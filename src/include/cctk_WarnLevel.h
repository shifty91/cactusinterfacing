#ifndef _CCTK_WARNLEVEL_H_
#define _CCTK_WARNLEVEL_H_

#include <stdio.h>
#include <stdlib.h>

/*
 * This file contains some routines for handling
 * warnings and output.
 *
 * WarnLevels taken from src/include/cctk_WarnLevel.h.
 */

/* suggested values for warning levels (courtesy of Steve, PR#1742) */
#define CCTK_WARN_ABORT    0    /* abort the Cactus run */
#define CCTK_WARN_ALERT    1    /* the results of this run will be wrong, */
                                /* and this will surprise the user, */
                                /* but we can still continue the run */
#define CCTK_WARN_COMPLAIN 2    /* the user should know about this, */
                                /* but the problem is not terribly */
                                /* surprising */
#define CCTK_WARN_PICKY    3    /* this is for small problems that can */
                                /* probably be ignored, but that careful */
                                /* people may want to know about */
#define CCTK_WARN_DEBUG    4    /* these messages are probably useful */
                                /* only for debugging purposes */

/*
 * These are the actual routines for printing
 * In Cactus these are functions, here just macro wrapper for
 * printf. Printf is used here, because the some of the function
 * expect format strings.
 */
#define CCTK_Warn(level, line, file, thorn, message)					\
	do {																\
		fprintf(stderr, "[%s WARNING %s:%d]: %s\n", (thorn), (file), (line), (message)); \
	} while (0)

#define CCTK_VWarn(level, line, file, thorn, format, ...)				\
	do {																\
		fprintf(stderr, "[%s WARNING %s:%d]: " format "\n", (thorn), (file), (line), __VA_ARGS__); \
	} while (0)


#define CCTK_Error(line, file, thorn, message)							\
	do {																\
		fprintf(stderr, "[%s ERROR %s:%d]: %s\n", (thorn), (file), (line), (message)); \
	} while (0)

#define CCTK_VError(line, file, thorn, format, ...)						\
	do {																\
		fprintf(stderr, "[%s WARNING %s:%d]: " format "\n", (thorn), (file), (line), __VA_ARGS__); \
	} while (0)

#define CCTK_ParamWarn(thorn, message)									\
	do {																\
		fprintf(stderr, "[%s PARAMWARNING]: %s\n", (thorn), (message)); \
	} while (0)

#define CCTK_VParamWarn(thorn, format, ...)								\
	do {																\
		fprintf(stderr, "[%s PARAMWARNING]: " format "\n", (thorn), __VA_ARGS__); \
	} while (0)

#define CCTK_Info(thorn, message)										\
	do {																\
		printf("[%s INFO]: %s\n", (thorn), (message));					\
	} while (0)

#define CCTK_VInfo(thorn, format, ...)									\
	do {																\
		printf("[%s INFO]: " format "\n", (thorn), __VA_ARGS__);		\
	} while (0)


#endif /* _CCTK_WARNLEVEL_H_ */
