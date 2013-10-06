#ifndef _CCTK_ARGUMENTS_H_
#define _CCTK_ARGUMENTS_H_

/*
 * This file contains macro definitions for
 * cactus functions arguments.
 */

/* not used in LibGeoDecomp */
#define CCTK_ARGUMENTS

/*
 * Insert variables for Cactus grid hirachy.
 */
#define DECLARE_CCTK_ARGUMENTS										\
	unsigned int const cctk_dim = cctkGH->cctk_dim();				\
	int *cctk_gsh = cctkGH->cctk_gsh();								\
	int *cctk_lsh = cctkGH->cctk_lsh();								\
	int *cctk_lbnd = cctkGH->cctk_lbnd();							\
	int *cctk_ubnd = cctkGH->cctk_ubnd();							\
	int *cctk_bbox = cctkGH->cctk_bbox();							\
	CCTK_REAL const cctk_delta_time = cctkGH->cctk_delta_time();	\
	CCTK_REAL const cctk_time = cctkGH->cctk_time();				\
	CCTK_REAL *cctk_delta_space = cctkGH->cctk_delta_space();		\
	CCTK_REAL *cctk_origin_space = cctkGH->cctk_origin_space();		\
	int *cctk_levfac = cctkGH->cctk_levfac();						\
	int *cctk_levoff = cctkGH->cctk_levoff();						\
	int *cctk_levoffdenom = cctkGH->cctk_levoffdenom();				\
	int *cctk_nghostzones = cctkGH->cctk_nghostzones();				\
	unsigned int const cctk_iteration = cctkGH->cctk_iteration();

/*
 * Defines for cactus scalar grid refinement
 * variables. The PUGH driver doesn't use grid
 * refinement, so these variables can be constant.
 */
#define cctk_timefac   1
#define cctk_convlevel 0
#define cctk_convfac   2

/*
 * Define for cctk_ash. PUGH sets it to
 * cctk_lsh.
 */
#define cctk_ash cctk_lsh


#endif /* _CCTK_ARGUMENTS_H_ */
