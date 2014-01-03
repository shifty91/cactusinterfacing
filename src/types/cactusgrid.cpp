#include "cactusgrid.h"

void CactusGrid::allocateMemory(unsigned int dim)
{
	// get some memory
	m_cctk_gsh          = new int[dim];
	m_cctk_lsh          = new int[dim];
	m_cctk_lbnd         = new int[dim];
	m_cctk_ubnd         = new int[dim];
	m_cctk_delta_space  = new CCTK_REAL[dim];
	m_cctk_origin_space = new CCTK_REAL[dim];
	m_cctk_bbox         = new int[2 * dim];
	m_cctk_levfac       = new int[dim];
	m_cctk_levoff       = new int[dim];
	m_cctk_levoffdenom  = new int[dim];
	m_cctk_nghostzones  = new int[dim];
}

void CactusGrid::freeMemory()
{
	// free memory
	delete[] m_cctk_gsh;
	delete[] m_cctk_lsh;
	delete[] m_cctk_lbnd;
	delete[] m_cctk_ubnd;
	delete[] m_cctk_delta_space;
	delete[] m_cctk_origin_space;
	delete[] m_cctk_bbox;
	delete[] m_cctk_levfac;
	delete[] m_cctk_levoff;
	delete[] m_cctk_levoffdenom;
	delete[] m_cctk_nghostzones;
}

CactusGrid::CactusGrid()
{
	unsigned int dim = 3;
	m_cctk_dim = dim;
	allocateMemory(dim);
}

CactusGrid::CactusGrid(unsigned int dim)
{
	m_cctk_dim = dim;
	allocateMemory(dim);
}

CactusGrid::CactusGrid(const CactusGrid& other)
{
	*this = other;
}

CactusGrid::~CactusGrid()
{
	freeMemory();
}

void CactusGrid::cctk_dim(unsigned int cctk_dim)
{
	if (m_cctk_dim >= cctk_dim) {
		m_cctk_dim = cctk_dim;
	} else {
		// save old data
		CactusGrid old = *this;
		// free old memory
		freeMemory();
		// allocate new memory with new dim
		allocateMemory(cctk_dim);
		// copy data
		copyData(old);
		// set new dim
		m_cctk_dim = cctk_dim;
	}
}

CactusGrid& CactusGrid::operator= (const CactusGrid& rhs)
{
	if (this == &rhs)
		return *this;

	// check dimension first
	if (m_cctk_dim != rhs.m_cctk_dim) {
		freeMemory();
		allocateMemory(rhs.m_cctk_dim);
		m_cctk_dim = rhs.m_cctk_dim;
	}

	// copy data
	copyData(rhs);

	return *this;
}


#ifdef DEBUG

#include <iostream>

#define PRINTPAR(name)										\
	do {													\
		std::cout << #name "=" << m_ ## name << std::endl;	\
	} while (0)


#define PRINTPARINDEX(name)												\
	do {																\
		for (unsigned int i = 0; i < m_cctk_dim; ++i) {					\
			std::cout << #name "[" << i << "]=" << m_ ## name[i] << std::endl; \
		}																\
	} while (0)

void CactusGrid::dumpCctkGH() const
{
	std::cout << "=================================" << std::endl;
	std::cout << "Dump of Cactus Grid Hierarchy"     << std::endl;
	std::cout << "=================================" << std::endl;
	PRINTPAR(cctk_dim);
	PRINTPAR(cctk_iteration);
	PRINTPARINDEX(cctk_gsh);
	PRINTPARINDEX(cctk_lsh);
	/*PRINTPARINDEX(cctk_lbnd);*/
	/*PRINTPARINDEX(cctk_ubnd);*/
	PRINTPAR(cctk_delta_time);
	PRINTPARINDEX(cctk_delta_space);
	PRINTPARINDEX(cctk_origin_space);
	/*PRINTPARINDEX(cctk_bbox);*/
	PRINTPARINDEX(cctk_levfac);
	PRINTPARINDEX(cctk_levoff);
	PRINTPARINDEX(cctk_levoffdenom);
	PRINTPARINDEX(cctk_nghostzones);
	PRINTPAR(cctk_time);
	std::cout << "=================================" << std::endl;
	std::cout << "End of Cactus Grid Hierarchy Dump" << std::endl;
	std::cout << "=================================" << std::endl;
}

#endif
