#ifndef _CCTK_TYPES_H_
#define _CCTK_TYPES_H_

#include <complex>
#include <cstring>
#include <stdint.h>

/*
 * Cactus data types.
 * Overrides types located in src/include/cctk_Types.h.
 *
 * CCTK_KEYWORD, CCTK_BOOLEAN got added for parameters.
 */
#define CCTK_BYTE             unsigned char
#define CCTK_CHAR             char
#define CCTK_INT              CCTK_INT4
#define CCTK_REAL             CCTK_REAL8
#define CCTK_COMPLEX          CCTK_COMPLEX16
#define CCTK_POINTER          void *
#define CCTK_POINTER_TO_CONST const void *
#define CCTK_STRING           std::string
/* keyword is just a string with some known values */
#define CCTK_KEYWORD          std::string
/* parameters can be BOOLEANs, too */
#define CCTK_BOOLEAN          bool

/*
 * Some of these types are available in different sizes.
 */
#define CCTK_INT1      int8_t
#define CCTK_INT2      int16_t
#define CCTK_INT4      int32_t
#define CCTK_INT8      int64_t
/* note: size of these may differ on different architectures */
#define CCTK_REAL4     float
#define CCTK_REAL8     double
#define CCTK_REAL16    long double
#define CCTK_COMPLEX8  std::complex<CCTK_REAL4>
#define CCTK_COMPLEX16 std::complex<CCTK_REAL8>
#define CCTK_COMPLEX32 std::complex<CCTK_REAL16>

#endif /* _CCTK_TYPES_H_ */
