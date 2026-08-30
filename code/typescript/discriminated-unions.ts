// A discriminated union: every member carries the same literal-typed field,
// so a switch on it narrows to exactly one shape.

type SensorEvent =
  | { type: "reading"; device: string; celsius: number }
  | { type: "offline"; device: string; since: string }
  | { type: "heartbeat"; at: string }
  | { type: "alarm"; device: string; reason: "temperature" | "battery"; value: number };

// The exhaustiveness check: if a member is added and not handled, `event`
// is no longer `never` here and the build fails.
function unreachable(value: never): never {
  throw new Error(`unhandled member: ${JSON.stringify(value)}`);
}

function describe(event: SensorEvent): string {
  switch (event.type) {
    case "reading":
      return `${event.device} reported ${event.celsius}C`;
    case "offline":
      return `${event.device} has been offline since ${event.since}`;
    case "heartbeat":
      return `heartbeat at ${event.at}`;
    case "alarm":
      return `${event.device} raised a ${event.reason} alarm (${event.value})`;
    default:
      return unreachable(event);
  }
}

const events: SensorEvent[] = [
  { type: "reading", device: "SNS-01", celsius: -18.4 },
  { type: "alarm", device: "SNS-04", reason: "temperature", value: 31.2 },
  { type: "offline", device: "SNS-09", since: "2025-11-03T04:00:00Z" },
  { type: "heartbeat", at: "2025-11-03T09:15:00Z" },
];

events.forEach((event) => console.log(describe(event)));

// Extract picks one member out of the union by its discriminant.
type Alarm = Extract<SensorEvent, { type: "alarm" }>;
type WithDevice = Extract<SensorEvent, { device: string }>;

function isAlarm(event: SensorEvent): event is Alarm {
  return event.type === "alarm";
}

const alarms: Alarm[] = events.filter(isAlarm);
console.log("alarms:", alarms.map((a) => a.reason));

const withDevice = events.filter((event): event is WithDevice => "device" in event);
console.log("devices:", withDevice.map((event) => event.device));

// The same pattern models a request's lifecycle, which removes the
// impossible states a flat object would allow.
type RequestState<T> =
  | { status: "idle" }
  | { status: "loading"; startedAt: number }
  | { status: "success"; data: T; loadedAt: number }
  | { status: "failure"; error: string; retries: number };

function render<T>(state: RequestState<T>): string {
  switch (state.status) {
    case "idle":
      return "nothing requested yet";
    case "loading":
      return `loading since ${state.startedAt}`;
    case "success":
      return `loaded ${JSON.stringify(state.data)}`;
    case "failure":
      return `failed after ${state.retries} retries: ${state.error}`;
  }
}

const states: RequestState<string[]>[] = [
  { status: "idle" },
  { status: "loading", startedAt: 1_762_161_300 },
  { status: "success", data: ["Alder Cross"], loadedAt: 1_762_161_400 },
  { status: "failure", error: "the upstream gave up", retries: 3 },
];
states.forEach((state) => console.log(" ", render(state)));

// A union of shapes without a discriminant needs `in` or a type guard, and
// gets awkward fast — which is the argument for adding one.
type Undiscriminated = { value: number } | { message: string };
function describeLoosely(value: Undiscriminated): string {
  return "value" in value ? `ok ${value.value}` : `error ${value.message}`;
}
console.log(describeLoosely({ value: 3 }), "|", describeLoosely({ message: "nope" }));
