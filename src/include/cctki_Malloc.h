#ifndef _CCTKI_MALLOC_H_
#define _CCTKI_MALLOC_H_

/* needed for malloc */
#include <stdlib.h>

/*
 * Cactus malloc functions track some information
 * about the allocations like file, line, size, etc.
 * This is why cactus needs special malloc functions.
 * In this case malloc/free shouldn't be needed, because
 * in c++ new/delete is used. But there may be code which uses
 * CCTKi_Malloc etc. Since those cactus functions do not abort
 * in case of an error, the functions become macros for
 * malloc/free.
 *
 * For Cactus' implementation have a look at src/util/Malloc.c
 * and src/include/cctki_Malloc.h.
 *
 */

#define CCTKi_Malloc(size, line, file)			\
	malloc((size))

#define CCTKi_Free(pointer, line, file)			\
	free((p))

#define CCTKi_Calloc(nmemb, size, line, file)	\
	calloc((nmemb),(size))

#define CCTKi_Realloc(pointer, size)			\
	realloc((pointer), (size))


#endif /* _CCTKI_MALLOC_H_ */
