#ifndef _CCTK_TYPES_H_
#define _CCTK_TYPES_H_

#include <complex>
#include <string>
#include <stdint.h>

/*
 * Cactus data types.
 * Overrides types located in src/include/cctk_Types.h.
 *
 * CCTK_KEYWORD, CCTK_BOOLEAN got added for parameters.
 */


/*
 * Some of these types are available in different sizes.
 */
typedef int8_t         CCTK_INT1;
typedef int16_t        CCTK_INT2;
typedef int32_t        CCTK_INT4;
typedef int64_t        CCTK_INT8;

/* note: size of these may differ on different architectures */
typedef float          CCTK_REAL4;
typedef double         CCTK_REAL8;
typedef long double    CCTK_REAL16;

typedef std::complex<CCTK_REAL4>  CCTK_COMPLEX8;
typedef std::complex<CCTK_REAL8>  CCTK_COMPLEX16;
typedef std::complex<CCTK_REAL16> CCTK_COMPLEX32;

typedef unsigned char  CCTK_BYTE;
typedef char           CCTK_CHAR;
typedef CCTK_INT4      CCTK_INT;
typedef CCTK_REAL8     CCTK_REAL;
typedef CCTK_COMPLEX16 CCTK_COMPLEX;
typedef void *         CCTK_POINTER;
typedef const void *   CCTK_POINTER_TO_CONST;
typedef std::string    CCTK_STRING;
/* keyword is just a string with some known values */
typedef std::string    CCTK_KEYWORD;
/* parameters can be BOOLEANs, too */
typedef bool           CCTK_BOOLEAN;

#endif /* _CCTK_TYPES_H_ */
