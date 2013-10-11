#ifndef _CACTUSGRID_H_
#define _CACTUSGRID_H_

#include <iostream>
#include <string>
#include "cctk_Types.h"

class CactusGrid
{
private:
	// Variables for cactus grid hierachy.
	// Void ***data, cGHGoupData *GroupData are not needed.
	// Removed cctk_timefac, cctk_convlevel, cctk_convfac, since
	// they're fixed values.
	// Removed cctk_ash, because PUGH sets it to cctk_lsh.

	unsigned int m_cctk_dim;	/**< dimension */
	unsigned int m_cctk_iteration; /**< current iteration */
	// do not use unsigned here, since cactus thorns expect this to be signed
	int *m_cctk_gsh;			/**< global grid size */
	int *m_cctk_lsh;			/**< local grid size */
	int *m_cctk_lbnd;			/**< lower bound */
	int *m_cctk_ubnd;			/**< upper bound */
	CCTK_REAL m_cctk_delta_time; /**< delta time */
	CCTK_REAL *m_cctk_delta_space; /**< delta space */
	CCTK_REAL *m_cctk_origin_space;	/**< origin space */
	int *m_cctk_bbox;			/**< indicates which edge is a real border */
	int *m_cctk_levfac;			/**< level factor */
	int *m_cctk_levoff;			/**< level off */
	int *m_cctk_levoffdenom;	/**< level off denom */
	int *m_cctk_nghostzones;	/**< size of ghostzones */
	CCTK_REAL m_cctk_time;		/**< current time step */
	std::string m_identity;		/**< identity */
	/**
	 * Allocates memory for variables in appropriate sizes.
	 *
	 * @param dim dimension of code (2D/3D/4D)
	 */
	void allocateMemory(unsigned int dim);
	/**
	 * Free memory allocated by allocateMemory().
	 *
	 */
	void freeMemory();
	/**
	 * Copies data from a other cactus grid hierarchy.
	 *
	 * @param rhs other cctkGH
	 */
	void copyData(const CactusGrid& rhs)
	{
		// copy data
		m_cctk_iteration  = rhs.m_cctk_iteration;
		m_cctk_delta_time = rhs.m_cctk_delta_time;
		m_cctk_time       = rhs.m_cctk_time;
		m_identity        = rhs.m_identity;
		for (unsigned int i = 0; i < m_cctk_dim; ++i) {
			m_cctk_gsh[i]          = rhs.m_cctk_gsh[i];
			m_cctk_lsh[i]          = rhs.m_cctk_lsh[i];
			m_cctk_lbnd[i]         = rhs.m_cctk_lbnd[i];
			m_cctk_ubnd[i]         = rhs.m_cctk_ubnd[i];
			m_cctk_delta_space[i]  = rhs.m_cctk_delta_space[i];
			m_cctk_origin_space[i] = rhs.m_cctk_origin_space[i];
			m_cctk_levfac[i]       = rhs.m_cctk_levfac[i];
			m_cctk_levoff[i]       = rhs.m_cctk_levoff[i];
			m_cctk_levoffdenom[i]  = rhs.m_cctk_levoffdenom[i];
			m_cctk_nghostzones[i]  = rhs.m_cctk_nghostzones[i];
		}
		for (unsigned int i = 0; i < (2 * m_cctk_dim + 1); ++i) {
			m_cctk_bbox[i] = rhs.m_cctk_bbox[i];
		}
	}

public:
	/**
	 * Constructor. Per default the dimension will be set to three.
	 * However, you can change the dimension later on by setting a new
	 * dimension by cctk_dim(int).
	 *
	 */
	CactusGrid();
	/**
	 * Constructor. Creates a cactus grid hierarchy in given dimenion.
	 *
	 * @param dim dimension
	 */
	CactusGrid(unsigned int dim);
	/**
	 * Deconstructor. Frees all allocated memory.
	 *
	 */
	~CactusGrid();
	/**
	 * Returns cctk_dim.
	 *
	 *
	 * @return cctk_dim
	 */
	unsigned int cctk_dim() const { return m_cctk_dim; }
	/**
	 * Sets new dimension.
	 * If new dim is greater than the old one,
	 * new memory will be allocated and the old
	 * content copied.
	 *
	 * @param cctk_dim new dimension
	 */
	void cctk_dim(unsigned int cctk_dim);
	/**
	 * Returns cctk_iteration.
	 *
	 *
	 * @return cctk_iteration
	 */
	unsigned int cctk_iteration() const { return m_cctk_iteration; }
	/**
	 * Sets cctk_iteration
	 *
	 * @param cctk_iteration new cctk_iteration
	 */
	void cctk_iteration(int cctk_iteration) { m_cctk_iteration = cctk_iteration; }
	/**
	 * Returns pointer to cctk_gsh.
	 *
	 *
	 * @return pointer to cctk_gsh
	 */
	int *cctk_gsh() const { return m_cctk_gsh; }
	/**
	 * Returns pointer to cctk_lsh.
	 *
	 *
	 * @return pointer to cctk_lsh
	 */
	int *cctk_lsh() const { return m_cctk_lsh; }
	/**
	 * Returns pointer to cctk_ubnd.
	 *
	 *
	 * @return pointer to cctk_ubnd
	 */
	int *cctk_ubnd() const { return m_cctk_ubnd; }
	/**
	 * Returns pointer to cctk_lbnd.
	 *
	 *
	 * @return pointer to cctk_lbnd
	 */
	int *cctk_lbnd() const { return m_cctk_lbnd; }
	/**
	 * Returns cctk_delta_time.
	 *
	 *
	 * @return cctk_delta_time
	 */
	CCTK_REAL cctk_delta_time() const { return m_cctk_delta_time; }
	/**
	 * Sets cctk_delta_time.
	 *
	 * @param cctk_delta_time new cctk_delta_time
	 */
	void cctk_delta_time(CCTK_REAL cctk_delta_time) { m_cctk_delta_time = cctk_delta_time; }
	/**
	 * Returns pointer to cctk_delta_space.
	 *
	 *
	 * @return pointer to cctk_delta_space
	 */
	CCTK_REAL *cctk_delta_space() const { return m_cctk_delta_space; }
	/**
	 * Returns pointer to cctk_origin_space.
	 *
	 *
	 * @return pointer to cctk_origin_space
	 */
	CCTK_REAL *cctk_origin_space() const { return m_cctk_origin_space; }
	/**
	 * Returns pointer to cctk_bbox.
	 *
	 *
	 * @return pointer to cctk_bbox
	 */
	int *cctk_bbox() const { return m_cctk_bbox; }
	/**
	 * Returns pointer to cctk_levfac.
	 *
	 *
	 * @return pointer to cctk_levfac
	 */
	int *cctk_levfac() const { return m_cctk_levfac; }
	/**
	 * Returns pointer to cctk_levoff.
	 *
	 *
	 * @return pointer to cctk_levoff
	 */
	int *cctk_levoff() const { return m_cctk_levoff; }
	/**
	 * Returns pointer to cctk_levoffdenom.
	 *
	 *
	 * @return pointer to cctk_levoffdenom
	 */
	int *cctk_levoffdenom() const { return m_cctk_levoffdenom; }
	/**
	 * Returns pointer to cctk_nghostzones.
	 *
	 *
	 * @return pointer to cctk_nghostzones
	 */
	int *cctk_nghostzones() const { return m_cctk_nghostzones; }
	/**
	 * Returns cctk_time.
	 *
	 *
	 * @return cctk_time
	 */
	CCTK_REAL cctk_time() const { return m_cctk_time; }
	/**
	 * Sets cctk_time.
	 *
	 * @param cctk_time new cctk_time
	 */
	void cctk_time(CCTK_REAL cctk_time) { m_cctk_time = cctk_time; }
	/**
	 * Returns reference to identity.
	 *
	 *
	 * @return identity
	 */
	const std::string& identity() const { return m_identity; }
	/**
	 * Sets identity.
	 *
	 * @param identity new identity
	 */
	void identity(const std::string& identity) { m_identity = identity; }
	/**
	 * Sets cctk_gsh to nsize in each direction.
	 *
	 * @param nsize nsize
	 */
	void cctk_gsh(int nsize)
	{
		unsigned int i;

		for (i = 0; i < m_cctk_dim; ++i) {
			m_cctk_gsh[i] = nsize;
		}
	}
	/**
	 * Sets cctk_lsh to nsize in each direction.
	 *
	 * @param nsize nsize
	 */
	void cctk_lsh(int nsize)
	{
		unsigned int i;

		for (i = 0; i < m_cctk_dim; ++i) {
			m_cctk_lsh[i] = nsize;
		}
	}
	/**
	 * Sets cctk_gsh to nsize in each direction.
	 *
	 * @param nsize nsize
	 */
	void cctk_delta_space(CCTK_REAL nsize)
	{
		unsigned int i;

		for (i = 0; i < m_cctk_dim; ++i) {
			m_cctk_delta_space[i] = nsize;
		}
	}
	/**
	 * Sets cctk_origin_space to nsize in each direction.
	 *
	 * @param nsize nsize
	 */
	void cctk_origin_space(CCTK_REAL nsize)
	{
		unsigned int i;

		for (i = 0; i < m_cctk_dim; ++i) {
			m_cctk_origin_space[i] = nsize;
		}
	}
	/**
	 * Sets cctk_levfac to nsize in each direction.
	 *
	 * @param nsize nsize
	 */
	void cctk_levfac(int nsize)
	{
		unsigned int i;

		for (i = 0; i < m_cctk_dim; ++i) {
			m_cctk_levfac[i] = nsize;
		}
	}
	/**
	 * Sets cctk_levoff to nsize in each direction.
	 *
	 * @param nsize nsize
	 */
	void cctk_levoff(int nsize)
	{
		unsigned int i;

		for (i = 0; i < m_cctk_dim; ++i) {
			m_cctk_levoff[i] = nsize;
		}
	}
	/**
	 * Sets cctk_levoffdenom to nsize in each direction.
	 *
	 * @param nsize nsize
	 */
	void cctk_levoffdenom(int nsize)
	{
		unsigned int i;

		for (i = 0; i < m_cctk_dim; ++i) {
			m_cctk_levoffdenom[i] = nsize;
		}
	}
	/**
	 * Sets cctk_nghostzones to nsize in each direction.
	 *
	 * @param nsize nsize
	 */
	void cctk_nghostzones(int nsize)
	{
		unsigned int i;

		for (i = 0; i < m_cctk_dim; ++i) {
			m_cctk_nghostzones[i] = nsize;
		}
	}
	/**
	 * Computes the minimum of cctk_delta_space.
	 * This is used for setting up cctk_delta_time.
	 *
	 * @return minimum of cctk_delta_space
	 */
	CCTK_REAL min_cctk_delta_space() const
	{
		CCTK_REAL min = m_cctk_delta_space[0];
		unsigned int i;

		for (i = 1; i < m_cctk_dim; ++i) {
			if (m_cctk_delta_space[i] < min)
				min = m_cctk_delta_space[i];
		}

		return min;
	}
	/**
	 * = Operator for assignments like
	 * CactusGrid c1 = c2;
	 *
	 * @param rhs second CactusGrid
	 *
	 * @return the old one which equals rhs
	 */
	CactusGrid& operator= (const CactusGrid& rhs);

#ifdef DEBUG
	/**
	 * Prints the cactus grid hierarchy to stdout.
	 * Meant for debugging purpose only.
	 *
	 */
	void dumpCctkGH() const;
#endif
};

#endif /* _CACTUSGRID_H_ */
