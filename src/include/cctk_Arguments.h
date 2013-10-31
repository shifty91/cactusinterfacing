#ifndef _CCTK_ARGUMENTS_H_
#define _CCTK_ARGUMENTS_H_

/*
 * This file contains macro definitions for
 * cactus functions arguments.
 */

/*
 * This is not needed. In LibGeoDecomp we use update functions
 * and therefore the functions declaration are constant.
 */
#define CCTK_ARGUMENTS

/*
 * This is not needed. Any variable will become a macro define.
 */
#define DECLARE_CCTK_ARGUMENTS

/*
 * Defines for cactus scalar grid refinement
 * variables. The PUGH driver doesn't use grid
 * refinement, so these variables can be constant.
 */
#define cctk_timefac   1
#define cctk_convlevel 0
#define cctk_convfac   2

/*
 * Define for cctk_ash. The PUGH driver sets it to cctk_lsh.
 */
#define cctk_ash cctk_lsh


#endif /* _CCTK_ARGUMENTS_H_ */
