/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#ifndef ricoh_theta_sample_for_ios_Constants_h
#define ricoh_theta_sample_for_ios_Constants_h

/** Camera FOV initial value */
#define CAMERA_FOV_DEGREE_INIT          (45.0f)
/** Camera FOV minimum value */
#define CAMERA_FOV_DEGREE_MIN           (30.0f)
/** Camera FOV maximum value */
#define CAMERA_FOV_DEGREE_MAX           (100.0f)
/** Z/NEAR for OpenGL perspective display */
#define Z_NEAR                          (0.1f)
/** Z/FA for OpenGL perspective display */
#define Z_FAR                           (100.0f)

/** Spherical radius for photo attachment */
#define SHELL_RADIUS                    (2.0f)
/** Number of spherical polygon partitions for photo attachment */
#define SHELL_DIVIDE                    (48)

/** Parameter for amount of rotation control (X axis) */
#define DIVIDE_ROTATE_X                 (500)
/** Parameter for amount of rotation control (Y axis) */
#define DIVIDE_ROTATE_Y                 (500)

/** Parameter for maximum width control */
#define SCALE_RATIO_TICK_EXPANSION      (1.05f)
/** Parameter for minimum width control */
#define SCALE_RATIO_TICK_REDUCTION      (0.95f)

#define KNUM_INTERVAL_INERTIA           (0.020)
#define INERTIA_1ST_SHORT_ADJUST(a)     (a / 3.0)
#define INERTIA_1ST_LONG_ADJUST(a)      (a / 2.0)
#define INERTIA_LONG_ADJUST(a)          (1.4 + a * 0.1)
#define INERTIA_SHORT_ADJUST(a)         (2.9 + a * 0.1)
#define INERTIA_NONE                    (1.0)
#define INERTIA_STOP_LIMT               (0.000002)

/** Amount of movement parameter for inertia (weak) */
#define WEAK_INERTIA_RATIO              (1.0)
/** Amount of movement parameter for inertia (strong) */
#define STRONG_INERTIA_RATIO            (10.0)

#endif
