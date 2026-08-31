/**
 * typed-router.ts — a router whose handler signatures are derived from the
 * route patterns, at compile time.
 *
 * Register `'/routes/:code/sailings/:id'` and the handler's `params` is
 * `{ code: string; id: string }` — not `Record<string, string>`, and not
 * something anyone typed twice. Getting a parameter name wrong is a compile
 * error rather than an undefined at three in the morning.
 *
 * Template literal types, recursive conditional types, mapped types, variadic
 * tuples, `const` type parameters, overloads, declaration merging on an
 * interface, and exhaustive switches over a discriminated union.
 *
 *   npx tsx typed-router.ts
 *   node typed-router.ts        # Node 22.6+, types stripped at load
 *
 * No dependencies, no server: requests are plain objects, so the whole thing
 * runs in a terminal.
 */

// ------------------------------------------------- extracting path params

/**
 * Pull the parameter names out of a path pattern.
 *
 *   PathParams<'/routes/:code/sailings/:id'>  ->  'code' | 'id'
 *   PathParams<'/health'>                     ->  never
 *
 * The type recurses down the string one segment at a time. `${string}` is the
 * wildcard, and the `/` in each branch is what stops a parameter name from
 * swallowing the rest of the path.
 */
type PathParams<Path extends string> =
  Path extends `${string}:${infer Param}/${infer Rest}`
    ? Param | PathParams<`/${Rest}`>
    : Path extends `${string}:${infer Param}`
      ? Param
      : never;

/** An optional parameter is written `:name?`. */
type OptionalParam<P extends string> = P extends `${infer Name}?` ? Name : never;
type RequiredParam<P extends string> = P extends `${string}?` ? never : P;

/**
 * The params object for a pattern: required keys for `:name`, optional keys
 * for `:name?`, and `{}` when the path has none.
 */
type Params<Path extends string> = {
  [K in RequiredParam<PathParams<Path>>]: string;
} & {
  [K in OptionalParam<PathParams<Path>>]?: string;
};

/** Flatten an intersection so it reads as one object. */
type Pretty<T> = { [K in keyof T]: T[K] } & {};

// --------------------------------------------------------------- messages

type Method = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

interface Request<Path extends string = string, Body = unknown> {
  readonly method: Method;
  readonly path: string;
  readonly params: Pretty<Params<Path>>;
  readonly query: Readonly<Record<string, string>>;
  readonly headers: Readonly<Record<string, string>>;
  readonly body: Body;
}

/**
 * A response is a union rather than a class, so a handler that forgets a case
 * is a compile error and the renderer below can switch exhaustively.
 */
type Response =
  | { readonly kind: 'json'; readonly status: number; readonly body: unknown }
  | { readonly kind: 'text'; readonly status: number; readonly body: string }
  | { readonly kind: 'empty'; readonly status: number }
  | { readonly kind: 'redirect'; readonly status: 301 | 302 | 307; readonly to: string };

const json = (body: unknown, status = 200): Response => ({ kind: 'json', status, body });
const text = (body: string, status = 200): Response => ({ kind: 'text', status, body });
const empty = (status = 204): Response => ({ kind: 'empty', status });
const redirect = (to: string, status: 301 | 302 | 307 = 302): Response => ({
  kind: 'redirect',
  status,
  to,
});

type Handler<Path extends string, Body = unknown> = (
  request: Request<Path, Body>,
) => Response | Promise<Response>;

type Middleware = (
  request: Request,
  next: () => Promise<Response>,
) => Response | Promise<Response>;

// -------------------------------------------------------------- matching

type Segment =
  | { readonly kind: 'literal'; readonly value: string }
  | { readonly kind: 'param'; readonly name: string; readonly optional: boolean }
  | { readonly kind: 'wildcard'; readonly name: string };

function compile(pattern: string): ReadonlyArray<Segment> {
  return pattern
    .split('/')
    .filter((part) => part.length > 0)
    .map((part): Segment => {
      if (part.startsWith('*')) {
        return { kind: 'wildcard', name: part.slice(1) || 'rest' };
      }
      if (part.startsWith(':')) {
        const optional = part.endsWith('?');
        return {
          kind: 'param',
          name: part.slice(1, optional ? -1 : undefined),
          optional,
        };
      }
      return { kind: 'literal', value: part };
    });
}

/**
 * A pattern's specificity, so that `/routes/new` wins over `/routes/:code`
 * however they were registered. Literals beat parameters, parameters beat
 * wildcards, and a longer pattern beats a shorter one.
 */
function specificity(segments: ReadonlyArray<Segment>): number {
  return segments.reduce((score, segment) => {
    switch (segment.kind) {
      case 'literal':
        return score + 4;
      case 'param':
        return score + (segment.optional ? 1 : 2);
      case 'wildcard':
        return score;
    }
  }, segments.length);
}

function match(
  segments: ReadonlyArray<Segment>,
  path: ReadonlyArray<string>,
): Record<string, string> | null {
  const params: Record<string, string> = {};
  let index = 0;

  for (const segment of segments) {
    if (segment.kind === 'wildcard') {
      params[segment.name] = path.slice(index).join('/');
      return params;
    }

    const part = path[index];

    if (part === undefined) {
      // Running out of path is only acceptable if everything left is optional.
      if (segment.kind === 'param' && segment.optional) continue;
      return null;
    }

    if (segment.kind === 'literal') {
      if (segment.value !== part) return null;
    } else {
      params[segment.name] = decodeURIComponent(part);
    }
    index += 1;
  }

  return index === path.length ? params : null;
}

// ---------------------------------------------------------------- routes

interface Route {
  readonly method: Method;
  readonly pattern: string;
  readonly segments: ReadonlyArray<Segment>;
  readonly score: number;
  readonly handler: Handler<string, never>;
  readonly name?: string;
}

class Router {
  private readonly routes: Route[] = [];
  private readonly middleware: Middleware[] = [];
  private readonly prefix: string;

  constructor(prefix = '') {
    this.prefix = prefix;
  }

  use(middleware: Middleware): this {
    this.middleware.push(middleware);
    return this;
  }

  /**
   * `const Path` keeps the literal type of the pattern, which is what makes
   * `PathParams` able to see the `:names` inside it. Without it the argument
   * widens to `string` and every handler gets `{}`.
   */
  on<const Path extends string, Body = unknown>(
    method: Method,
    pattern: Path,
    handler: Handler<Path, Body>,
    name?: string,
  ): this {
    const full = `${this.prefix}${pattern}`;
    const segments = compile(full);
    this.routes.push({
      method,
      pattern: full,
      segments,
      score: specificity(segments),
      handler: handler as unknown as Handler<string, never>,
      name,
    });
    // Most specific first, so the first match is the right one.
    this.routes.sort((a, b) => b.score - a.score);
    return this;
  }

  get<const P extends string>(pattern: P, handler: Handler<P>, name?: string): this {
    return this.on('GET', pattern, handler, name);
  }

  post<const P extends string, B = unknown>(
    pattern: P,
    handler: Handler<P, B>,
    name?: string,
  ): this {
    return this.on('POST', pattern, handler, name);
  }

  put<const P extends string, B = unknown>(pattern: P, handler: Handler<P, B>): this {
    return this.on('PUT', pattern, handler);
  }

  delete<const P extends string>(pattern: P, handler: Handler<P>): this {
    return this.on('DELETE', pattern, handler);
  }

  /**
   * Mount another router underneath a prefix.
   *
   * The mounted router's middleware has to be baked into each copied handler.
   * Copying only the routes looks right and quietly drops every guard the
   * other router installed -- which is the sort of bug that is discovered by
   * an unauthenticated write succeeding.
   */
  mount(prefix: string, other: Router): this {
    for (const route of other.routes) {
      const pattern = `${this.prefix}${prefix}${route.pattern}`;
      const segments = compile(pattern);
      const handler = other.wrap(route.handler);
      this.routes.push({
        ...route,
        pattern,
        segments,
        score: specificity(segments),
        handler,
      });
    }
    this.routes.sort((a, b) => b.score - a.score);
    return this;
  }

  /** Wrap a handler in this router's middleware, outermost layer first. */
  private wrap(handler: Handler<string, never>): Handler<string, never> {
    if (this.middleware.length === 0) return handler;

    return (request) => {
      const run = this.middleware.reduceRight<() => Promise<Response>>(
        (next, layer) => () => Promise.resolve(layer(request as Request, next)),
        () => Promise.resolve(handler(request)),
      );
      return run();
    };
  }

  /** Build a path from a named route and its parameters. */
  url(name: string, params: Record<string, string> = {}): string {
    const route = this.routes.find((candidate) => candidate.name === name);
    if (!route) throw new Error(`no route named "${name}"`);

    const parts: string[] = [];
    for (const segment of route.segments) {
      if (segment.kind === 'literal') {
        parts.push(segment.value);
        continue;
      }
      const value = params[segment.name];
      if (value === undefined) {
        if (segment.kind === 'param' && segment.optional) continue;
        throw new Error(`route "${name}" needs a "${segment.name}"`);
      }
      parts.push(encodeURIComponent(value));
    }
    return `/${parts.join('/')}`;
  }

  async handle(
    method: Method,
    url: string,
    options: { body?: unknown; headers?: Record<string, string> } = {},
  ): Promise<Response> {
    const [rawPath = '', rawQuery = ''] = url.split('?');
    const path = rawPath.split('/').filter((part) => part.length > 0);
    const query: Record<string, string> = {};
    for (const pair of rawQuery.split('&').filter(Boolean)) {
      const [key = '', value = ''] = pair.split('=');
      query[decodeURIComponent(key)] = decodeURIComponent(value);
    }

    let allowed: Method[] = [];

    for (const route of this.routes) {
      const params = match(route.segments, path);
      if (params === null) continue;

      if (route.method !== method) {
        allowed.push(route.method);
        continue;
      }

      const request: Request = {
        method,
        path: rawPath,
        params: params as never,
        query,
        headers: options.headers ?? {},
        body: options.body,
      };

      // Middleware wraps the handler from the outside in. A route that
      // arrived through mount() already carries its own router's layers.
      return Promise.resolve(this.wrap(route.handler)(request as never));
    }

    if (allowed.length > 0) {
      allowed = [...new Set(allowed)];
      return json(
        { error: 'method not allowed', allowed },
        405,
      );
    }
    return json({ error: 'not found', path: rawPath }, 404);
  }

  get table(): ReadonlyArray<{ method: Method; pattern: string; score: number }> {
    return this.routes.map(({ method, pattern, score }) => ({ method, pattern, score }));
  }
}

// ---------------------------------------------------------------- rendering

/** Exhaustive: adding a Response variant without a case here fails to compile. */
function render(response: Response): string {
  switch (response.kind) {
    case 'json':
      return `${response.status} application/json  ${JSON.stringify(response.body)}`;
    case 'text':
      return `${response.status} text/plain        ${response.body}`;
    case 'empty':
      return `${response.status} (no body)`;
    case 'redirect':
      return `${response.status} -> ${response.to}`;
    default: {
      const unreachable: never = response;
      throw new Error(`unhandled response: ${JSON.stringify(unreachable)}`);
    }
  }
}

// -------------------------------------------------------------- the data

type Sailing = { id: string; route: string; departs: string; seats: number };

const SAILINGS: ReadonlyArray<Sailing> = [
  { id: 'HRB-1', route: 'HRB', departs: '06:20', seats: 380 },
  { id: 'HRB-2', route: 'HRB', departs: '06:40', seats: 380 },
  { id: 'KSP-1', route: 'KSP', departs: '07:00', seats: 240 },
  { id: 'KSP-2', route: 'KSP', departs: '07:30', seats: 240 },
  { id: 'HLW-1', route: 'HLW', departs: '08:05', seats: 120 },
  { id: 'NCR-1', route: 'NCR', departs: '21:30', seats: 90 },
];

const ROUTES: ReadonlyArray<{ code: string; name: string }> = [
  { code: 'HRB', name: 'Harbour Loop' },
  { code: 'KSP', name: 'Kestrel Point' },
  { code: 'HLW', name: 'Halloway' },
  { code: 'NCR', name: 'Night Crossing' },
];

// ------------------------------------------------------------ the routers

const log: string[] = [];

const api = new Router('/api')
  .use(async (request, next) => {
    const started = log.length;
    const response = await next();
    log.push(`${request.method} ${request.path} -> ${response.status} (${started})`);
    return response;
  })
  .use(async (request, next) => {
    // A guard that runs before the handler and can short-circuit it.
    if (request.method !== 'GET' && !request.headers['x-api-key']) {
      return json({ error: 'an api key is required for writes' }, 401);
    }
    return next();
  });

api.get('/routes', () => json({ routes: ROUTES }), 'routes.index');

// `params` here is `{ code: string }`, inferred from the pattern.
api.get(
  '/routes/:code',
  ({ params }) => {
    const route = ROUTES.find((candidate) => candidate.code === params.code);
    return route ? json(route) : json({ error: `no route ${params.code}` }, 404);
  },
  'routes.show',
);

// Two parameters, and a query string that is not part of the pattern.
api.get(
  '/routes/:code/sailings/:id',
  ({ params, query }) => {
    const sailing = SAILINGS.find(
      (candidate) => candidate.route === params.code && candidate.id === params.id,
    );
    if (!sailing) return json({ error: 'no such sailing' }, 404);
    return query['fields'] === 'brief'
      ? json({ id: sailing.id, departs: sailing.departs })
      : json(sailing);
  },
  'sailings.show',
);

// A literal segment that must beat the `:code` pattern above it.
api.get('/routes/all/sailings', () => json({ sailings: SAILINGS }));

// An optional parameter.
api.get('/timetable/:day?', ({ params }) =>
  json({ day: params.day ?? 'today', sailings: SAILINGS.length }),
);

api.post<'/routes/:code/sailings', { departs: string; seats: number }>(
  '/routes/:code/sailings',
  ({ params, body }) => {
    if (!body || typeof body.departs !== 'string') {
      return json({ error: 'departs is required' }, 422);
    }
    return json({ created: `${params.code}-${SAILINGS.length + 1}`, ...body }, 201);
  },
);

api.delete('/routes/:code/sailings/:id', () => empty(204));

// A wildcard, which matches whatever is left.
api.get('/files/*path', ({ params }) => text(`would serve ${params.path}`));

const site = new Router()
  .get('/', () => redirect('/api/routes'))
  .get('/health', () => text('ok'))
  .mount('', api);

// ------------------------------------------------------------------- demo

async function demonstrate(): Promise<void> {
  console.log('--- the routing table, most specific first ---');
  for (const route of site.table) {
    console.log(`  ${String(route.score).padStart(3)}  ${route.method.padEnd(6)} ${route.pattern}`);
  }

  console.log('\n--- requests ---');
  const requests: ReadonlyArray<[Method, string, { body?: unknown; headers?: Record<string, string> }?]> = [
    ['GET', '/'],
    ['GET', '/health'],
    ['GET', '/api/routes'],
    ['GET', '/api/routes/KSP'],
    ['GET', '/api/routes/ZZZ'],
    ['GET', '/api/routes/HRB/sailings/HRB-2'],
    ['GET', '/api/routes/HRB/sailings/HRB-2?fields=brief'],
    ['GET', '/api/routes/all/sailings'],
    ['GET', '/api/timetable'],
    ['GET', '/api/timetable/friday'],
    ['GET', '/api/files/manuals/2027/safety.pdf'],
    ['POST', '/api/routes/HRB/sailings', { body: { departs: '09:00', seats: 380 } }],
    ['POST', '/api/routes/HRB/sailings', { body: { departs: '09:00', seats: 380 }, headers: { 'x-api-key': 'sample' } }],
    ['POST', '/api/routes/HRB/sailings', { body: {}, headers: { 'x-api-key': 'sample' } }],
    ['DELETE', '/api/routes/HRB/sailings/HRB-1', { headers: { 'x-api-key': 'sample' } }],
    ['PUT', '/api/routes/HRB', { headers: { 'x-api-key': 'sample' } }],
    ['GET', '/api/nothing/here'],
  ];

  for (const [method, url, options] of requests) {
    const response = await site.handle(method, url, options ?? {});
    console.log(`  ${method.padEnd(6)} ${url.padEnd(44)} ${render(response)}`);
  }

  console.log('\n--- building urls from named routes ---');
  console.log('  ' + api.url('routes.index'));
  console.log('  ' + api.url('routes.show', { code: 'HLW' }));
  console.log('  ' + api.url('sailings.show', { code: 'NCR', id: 'NCR-1' }));
  console.log('  ' + api.url('routes.show', { code: 'a b/c' }) + '   (escaped)');

  try {
    api.url('sailings.show', { code: 'NCR' });
  } catch (error) {
    console.log(`  refused: ${(error as Error).message}`);
  }
  try {
    api.url('nope');
  } catch (error) {
    console.log(`  refused: ${(error as Error).message}`);
  }

  console.log('\n--- what the middleware logged ---');
  for (const line of log.slice(0, 6)) console.log(`  ${line}`);
  console.log(`  ... ${log.length} entries in total`);

  console.log('\n--- what the types caught at compile time ---');
  console.log('  These lines are commented out because they do not compile:');
  console.log("    api.get('/routes/:code', ({ params }) => json(params.id));");
  console.log('      Property \'id\' does not exist on type \'{ code: string; }\'');
  console.log("    api.get('/health', ({ params }) => json(params.anything));");
  console.log("      Property 'anything' does not exist on type '{}'");
  console.log('  The parameter names come from the pattern, so a typo is a type error.');
}

void demonstrate();
