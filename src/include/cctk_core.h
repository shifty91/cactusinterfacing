#ifndef _CCTK_CORE_H_
#define _CCTK_CORE_H_

/* include all overloaded Cactus macros/functions */
#include "cctk_Types.h"
#include "cctk_Parameters.h"
#include "cctk_Arguments.h"
#include "cctk_WarnLevel.h"
#include "cctk_Misc.h"
#include "cctki_Malloc.h"

/*
 * Cctk macros taken from src/include/cctk_core.h.
 * Removed variables for grid refinement.
 */
#define CCTK_ORIGIN_SPACE(x)					\
	(cctk_origin_space[x]+cctk_delta_space[x])
#define CCTK_DELTA_SPACE(x)						\
	(cctk_delta_space[x])
#define CCTK_DELTA_TIME							\
	(cctk_delta_time)

/* implemented in cctk_Misc.h */
#define CCTK_EQUALS(a,b)						\
	(CCTK_Equals((a),(b)))

#define CCTK_PASS_CTOC							\
	cctkGH

/* implemented in cctk_WarnLevel.h */
#define CCTK_WARN(a,b)									\
	CCTK_Warn(a, __LINE__, __FILE__, CCTK_THORNSTRING,b)
#define CCTK_ERROR(b)									\
	CCTK_Error(__LINE__, __FILE__, CCTK_THORNSTRING,b)
#define CCTK_INFO(a)							\
	CCTK_Info(CCTK_THORNSTRING,(a))
#define CCTK_PARAMWARN(a)						\
	CCTK_ParamWarn(CCTK_THORNSTRING,(a))

/* implemented in cctki_Malloc.h */
#define CCTK_MALLOC(s)							\
	CCTKi_Malloc(s, __LINE__, __FILE__)
#define CCTK_FREE(p)							\
	CCTKi_Free(p)

#endif /* _CCTK_CORE_H_ */
