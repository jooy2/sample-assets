/* A header-only 2D vector: include guards, a typedef, and static inline
   functions that need no separate .c file. */

#ifndef VECTOR2_H
#define VECTOR2_H

#include <math.h>

typedef struct {
    double x;
    double y;
} Vector2;

static inline Vector2 vector2_make(double x, double y)
{
    Vector2 vector = {x, y};
    return vector;
}

static inline Vector2 vector2_add(Vector2 a, Vector2 b)
{
    return vector2_make(a.x + b.x, a.y + b.y);
}

static inline Vector2 vector2_scale(Vector2 vector, double factor)
{
    return vector2_make(vector.x * factor, vector.y * factor);
}

static inline double vector2_dot(Vector2 a, Vector2 b)
{
    return a.x * b.x + a.y * b.y;
}

static inline double vector2_length(Vector2 vector)
{
    return sqrt(vector2_dot(vector, vector));
}

/* Returns the zero vector unchanged rather than dividing by zero. */
static inline Vector2 vector2_normalize(Vector2 vector)
{
    double length = vector2_length(vector);

    return length == 0.0 ? vector : vector2_scale(vector, 1.0 / length);
}

#endif /* VECTOR2_H */
