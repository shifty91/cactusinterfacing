#ifndef _CCTK_MISC_H_
#define _CCTK_MISC_H_

#include <boost/algorithm/string.hpp>

/*
 * Some Cactus Utility functions.
 */

#define CCTK_Equals(str1, str2)						\
	boost::algorithm::iequals((str1), (str2))		\

#endif /* _CCTK_MISC_H_ */
