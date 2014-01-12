#ifndef _PARPARSER_H_
#define _PARPARSER_H_

#include <stdexcept>
#include <sstream>
#include <string>
#include <map>
#include "cctk_Types.h"			// cactus data types like CCTK_REAL
#include "cactusgrid.h"			// cactusgrid to setup

/**
 * @file   parparser.h
 *
 * @brief Parameter file parser for Cactus parameter files.
 *
 * This parser has two different tasks. First of all it sets
 * the parameter of the thorns to the given values. Unknown
 * parameter are ignored. Next is, it sets up a CactusGrid
 * hierarchy by evaluating the parameters for the cactus flesh
 * and CactusBase thorns. If anything goes wrong a exception
 * will be thrown.
 *
 * Example usage:
 *   ParParser parser(paramFile);
 *   parser.parse();
 *   CactusGrid *myCactusGrid = parser.getCctkGH();
 *   // do something with it ...
 *   delete myCactusGrid;
 *
 */
class ParParser
{
private:
	bool m_parsed;
	const char *m_file;			/**< parameter file */
	std::map<std::string, std::string> m_parMap; /**< hash map to store parsing result */
	CactusGrid *m_cctkGH;		/**< cactus grid hierachy to set up */
	int m_globalNSize;			/**< global grid size */
	int m_global[3];			/**< global grid size in each direction */
	int m_localNSize;			/**< local grid size */
	int m_local[3];				/**< local grid size in each direction */
	std::string m_gridType;		/**< grid type */
	std::string m_domain;		/**< grid domain */
	bool m_avoidOriginNSize;	/**< avoid origin */
	bool m_avoidOrigin[3];		/**< avoid origin in each direction */
	CCTK_REAL m_dxyz;			/**< delta space */
	CCTK_REAL m_d[3];			/**< delta space in each direction */
	CCTK_REAL m_xyzmax;			/**< maximum */
	CCTK_REAL m_max[3];			/**< maximum in each direction */
	CCTK_REAL m_xyzmin;			/**< minimum */
	CCTK_REAL m_min[3];			/**< minimum in each direction */
	std::string m_timeMethod;	/**< time method */
	CCTK_REAL m_dtfac;			/**< delta time factor */
	CCTK_REAL m_courant_fac;	/**< courant factor */
	CCTK_REAL m_courant_speed;	/**< courant speed */
	CCTK_REAL m_courant_min_time; /**< courant minimum time */
	unsigned  m_it_max;			/**< maximum iteration */
	unsigned  m_hdf5_out;		/**< hdf5 output frequency */
	/**
	 * Parses a line of parameter file
	 * and stores impl::name and value into the hash map.
	 *
	 * This function uses perl like regex from boost library.
	 *
	 * @param line to parse
	 *
	 */
	void parseLine(const std::string& line);
	/**
	 * Similar to .equalsIgnoreCase in Java.
	 * This is needed, because cactus doesn't care about
	 * the case.
	 *
	 * @param str1
	 * @param str2
	 *
	 * @return
	 */
	bool equals(const std::string& str1, const std::string& str2) const;
	/**
	 * Checks if a parameter is given.
	 *
	 * @param key
	 *
	 * @return
	 */
	bool exists(const std::string& key) const;
	/**
	 * Get the value by impl::name of parameter.
	 *
	 * @param key
	 *
	 * @return
	 */
	std::string getString(const std::string& key) const;
	/**
	 * Prepares values for further processing, including:
	 *  - removes ""
	 *  - trim values
	 *  - cactus boolean into c++ bool.
	 *
	 */
	void prepareValues(void);
	/**
	 * Inits the cactus grid hierarchy with default values.
	 *
	 */
	void initCctkDefaults(void);
	/**
	 * Inits the base thorn parameters with default values.
	 *
	 */
	void initThornDefaults(void);
	/**
	 * Meta function for init everything with default values.
	 *
	 */
	void initDefaults(void);
	/**
	 * Sets cctk_iteration.
	 *
	 */
	void proceedCactus(void);
	/**
	 * PUGH sets
	 *  - cctk_gsh
	 *  - cctk_lsh
	 * See CactusPUGH/PUGH.
	 *
	 */
	void proceedPUGH(void);
	/**
	 * Helper function for proceedCartGrid().
	 * This function applys the symmetry to the grid.
	 * Make sure all needed variables are set up.
	 *
	 */
	void setupSymmetry(void);
	/**
	 * CartGrid3D sets
	 *  - cctk_delta_space
	 *  - cctk_origin_space.
	 * See CactusBase/CartGrid3D.
	 *
	 */
	void proceedCartGrid(void);
	/**
	 * Time sets cctk_delta_time.
	 * See CactusBase/Time.
	 *
	 */
	void proceedTime(void);
	/**
	 * Gets the parameters from the HDF5 thorn.
	 *
	 */
	void proceedHDF5(void);
	/**
	 * Converts a string into type given by T.
	 *
	 * @param s string to convert
	 *
	 * @return value in type T
	 */
	template<class T>
	T fromString(const std::string& s)
	{
		std::istringstream stream (s);
		T t;
		stream >> t;
		if (stream.fail()) {
			throw std::invalid_argument("Failed to convert " + s);
		}
		return t;
	}
public:
	/**
	 * Constructor.
	 * Allocates a new CactusGrid hierarchy.
	 *
	 * @param file path/to/file, c style
	 */
	ParParser(const char *file);
	/**
	 * Constructor.
	 * Allocates a new CactusGrid hierarchy.
	 *
	 * @param file /path/to/file, c++ style
	 */
	ParParser(const std::string& file);
	/**
	 * Copy constructor.
	 *
	 * @param parser
	 */
	ParParser(const ParParser& parser);
	/**
	 * Deconstructor. Does nothing.
	 * The cactus grid hierarchy has to be freed by user.
	 *
	 */
	virtual ~ParParser() {}
	/**
	 * Parses the parameter file as given by file and setups all parameters.
	 *
	 */
	void parse();
	/**
	 * Returns a pointer to cactus grid hierarchy.
	 * Note: The caller has to free that object and call parse() first.
	 *
	 * @return pointer to cctkGH
	 */
	inline CactusGrid *getCctkGH() const
	{
		if (!m_parsed)
			throw std::logic_error("ParParser: Call parse() first!");

		return m_cctkGH;
	}
	/**
	 * Gets the specified maximum number of iterations.
	 * Note: Call parse() first.
	 *
	 * @return maximum number of iterations
	 */
	inline const unsigned& itMax() const
	{
		if (!m_parsed)
			throw std::logic_error("ParParser: Call parse() first!");

		return m_it_max;
	}
	/**
	 * Gets the output frequency specified by HDF5 thorn.
	 * Note: Call parse() first.
	 *
	 * @return hdf5 output frequency
	 */
	inline const unsigned& Hdf5Out() const
	{
		if (!m_parsed)
			throw std::logic_error("ParParser: Call parse() first!");

		return m_hdf5_out;
	}
};

#endif /* _PARPARSER_H_ */
