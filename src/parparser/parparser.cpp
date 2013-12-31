#include "parparser.h"

#include <fstream>
#include <boost/regex.hpp>
#include <boost/algorithm/string.hpp>
#include <cmath>
#include "cell.h"
#include "init.h"
#include "parameter.h"			// contains parsed parameter descriptions

/**
 * Checks whether an parameter is given and
 * sets it into variable toSet in correct type.
 *
 * @param name
 * @param type
 * @param toSet
 *
 * @return
 */
#define GET(name, type, toSet)							\
	do {												\
		if (exists(#name)) {							\
			toSet = fromString<type>(getString(#name));	\
		}												\
	} while (0)

/**
 * Checks whether an parameter is given and
 * sets it directly into cactus grid hierarchy.
 *
 * @param name
 * @param type
 * @param toSet
 *
 * @return
 */
#define CGETANDSET(name, type, toSet)						\
	do {													\
		if (exists(#name)) {								\
			type tmp = fromString<type>(getString(#name));	\
			m_cctkGH->toSet(tmp);							\
		}													\
	} while (0)

ParParser::ParParser(const char *file) :
	m_parsed(false), m_file(file)
{
	unsigned int dim = CCTKGHDIM;
	m_cctkGH         = new CactusGrid(dim);

	// use default values
	initDefaults();
}

ParParser::ParParser(const std::string& file) :
	m_parsed(false), m_file(file.c_str())
{
	unsigned int dim = CCTKGHDIM;
	m_cctkGH         = new CactusGrid(dim);

	// use default values
	initDefaults();
}

bool ParParser::exists(const std::string& key) const
{
	std::string copy = boost::algorithm::to_lower_copy(key);

	return m_parMap.count(copy) > 0;
}

std::string ParParser::getString(const std::string& key) const
{
	std::string copy = boost::algorithm::to_lower_copy(key);

	return m_parMap.find(copy)->second;
}

bool ParParser::equals(const std::string& str1, const std::string& str2) const
{
	return boost::iequals(str1, str2);
}

void ParParser::initCctkDefaults(void)
{
	// init cactus
	m_cctkGH->cctk_iteration(0);
	m_cctkGH->cctk_time(0);

	// init cactus int* variables for grid refinement
	m_cctkGH->cctk_levfac(1);
	m_cctkGH->cctk_levoff(0);
	m_cctkGH->cctk_levoffdenom(1);
	m_cctkGH->cctk_bbox(0);

	// set ghostzones to 1
	m_cctkGH->cctk_nghostzones(1);
}

void ParParser::initThornDefaults(void)
{
	// CactusPUGH/PUGH
	m_globalNSize = -1;
	m_global[0]   = 10;
	m_global[1]   = 10;
	m_global[2]   = 10;
	m_localNSize  = -1;
	m_local[0]    = -1;
	m_local[1]    = -1;
	m_local[2]    = -1;

	// CactusBase/CartGrid3D
	m_gridType         = "box";
	m_domain           = "full";
	m_avoidOriginNSize = true;
	m_avoidOrigin[0]   = true;
	m_avoidOrigin[1]   = true;
	m_avoidOrigin[2]   = true;
	m_dxyz             = 0.0;
	m_d[0]             = 0.3;
	m_d[1]             = 0.3;
	m_d[2]             = 0.3;
	m_xyzmax           = -424242;
	m_xyzmin           = -424242;
	m_min[0]           = -1.0;
	m_min[1]           = -1.0;
	m_min[2]           = -1.0;
	m_max[0]           = 1.0;
	m_max[1]           = 1.0;
	m_max[2]           = 1.0;

	// CactusBase/Time
	m_timeMethod       = "courant_static";
	m_dtfac            = 0.0;
	m_courant_fac      = 0.9;
	m_courant_speed    = 0.0;
	m_courant_min_time = 0.0;
}

void ParParser::initDefaults(void)
{
	initCctkDefaults();
	initThornDefaults();
}

void ParParser::proceedCactus(void)
{
	GET(cactus::cctk_itlast, unsigned int, m_it_max);
}

void ParParser::proceedPUGH(void)
{
	unsigned int i;
	unsigned int dim = m_cctkGH->cctk_dim();

	// get parameter
	GET(driver::global_nsize, int, m_globalNSize);
	GET(driver::global_nx,    int, m_global[0]);
	GET(driver::global_ny,    int, m_global[1]);
	GET(driver::global_nz,    int, m_global[2]);
	GET(driver::local_nsize,  int, m_localNSize);
	GET(driver::local_nx,     int, m_local[0]);
	GET(driver::local_ny,     int, m_local[1]);
	GET(driver::local_nz,     int, m_local[2]);

	// local given
	if (m_localNSize > 0) {
		m_local[0] = m_local[1] = m_local[2] = m_localNSize;
	}
	if (m_local[0] > 0 && m_local[1] > 0 && m_local[2] > 0) {
		for (i = 0; i < dim; ++i) {
			m_cctkGH->cctk_gsh()[i] = m_local[i];
			m_cctkGH->cctk_lsh()[i] = m_local[i];
		}

		return;
	}

	// global given
	if (m_globalNSize > 0)
		m_global[0] = m_global[1] = m_global[2] = m_globalNSize;

	for (i = 0; i < dim; ++i) {
		m_cctkGH->cctk_gsh()[i] = m_global[i];
		m_cctkGH->cctk_lsh()[i] = m_global[i];
	}
}

void ParParser::setupSymmetry(void)
{
	int i;
	bool quadrant    = false;
	unsigned int dim = m_cctkGH->cctk_dim();

	if (equals(m_domain, "bitant")) {
		// z >= 0
		i = 0;
	} else if (equals(m_domain, "quadrant")) {
		// x >= 0, y >= 0
		i = 1;
		quadrant = true;
	} else if (equals(m_domain, "octant")) {
		// z >= 0, y >= 0, x >= 0
		i = 2;
	} else if (equals(m_domain, "full")) {
		// nothing to do here
		return;
	} else {
		throw std::invalid_argument("Unknown Domain " + m_domain);
		return;
	}

	// apply symmetry
	for (; i >= 0; --i) {
		unsigned int x = quadrant ? i : 2 - i;
		if (x >= dim)
			continue;
		if (m_avoidOrigin[x]) {
			m_cctkGH->cctk_origin_space()[x] = -m_cctkGH->cctk_delta_space()[x] / 2.0;
		} else {
			m_cctkGH->cctk_origin_space()[x] = -m_cctkGH->cctk_delta_space()[x];
		}
	}
}

void ParParser::proceedCartGrid(void)
{
	unsigned int i;
	unsigned int dim = m_cctkGH->cctk_dim();

	// get Type
	GET(grid::type, std::string, m_gridType);

	// get domain
	GET(grid::domain, std::string, m_domain);

	// get avoid origin
	GET(grid::avoid_origin , bool, m_avoidOriginNSize);
	GET(grid::avoid_originx, bool, m_avoidOrigin[0]);
	GET(grid::avoid_originy, bool, m_avoidOrigin[1]);
	GET(grid::avoid_originz, bool, m_avoidOrigin[2]);
	if (!m_avoidOriginNSize)
		m_avoidOrigin[0] = m_avoidOrigin[1] = m_avoidOrigin[2] = false;

	if (equals(m_gridType, "box")) {
		// grid::xyzmin = -0.5, grid::xyzmax = +0.5
		m_cctkGH->cctk_origin_space(-0.5);
		for (i = 0; i < dim; ++i)
			m_cctkGH->cctk_delta_space()[i] = 1.0 / m_cctkGH->cctk_gsh()[i];
	} else if (equals(m_gridType, "byrange")) {
		// get ranges
		GET(grid::xyzmax, CCTK_REAL, m_xyzmax);
		GET(grid::xyzmin, CCTK_REAL, m_xyzmin);
		GET(grid::xmax, CCTK_REAL, m_max[0]);
		GET(grid::ymax, CCTK_REAL, m_max[1]);
		GET(grid::zmax, CCTK_REAL, m_max[2]);
		GET(grid::xmin, CCTK_REAL, m_min[0]);
		GET(grid::ymin, CCTK_REAL, m_min[1]);
		GET(grid::zmin, CCTK_REAL, m_min[2]);

		if (m_xyzmax != -424242)
			m_max[0] = m_max[1] = m_max[2] = m_xyzmax;
		if (m_xyzmin != -424242)
			m_min[0] = m_min[1] = m_min[2] = m_xyzmin;

		// set origin
		for (i = 0; i < dim; ++i) {
			m_cctkGH->cctk_origin_space()[i] = m_min[i];

			// compute spacing
			m_cctkGH->cctk_delta_space()[i] = (m_max[i] - m_min[i]) /
				(m_cctkGH->cctk_gsh()[i] - 1);
		}
	} else if (equals(m_gridType, "byspacing")) {
		// get spacings
		GET(grid::dxyz, CCTK_REAL, m_dxyz);
		GET(grid::dx, CCTK_REAL, m_d[0]);
		GET(grid::dy, CCTK_REAL, m_d[1]);
		GET(grid::dz, CCTK_REAL, m_d[2]);

		if (m_dxyz > 0.0)
			m_d[0] = m_d[1] = m_d[2] = m_dxyz;

		// set spacings
		for (i = 0; i < dim; ++i) {
			m_cctkGH->cctk_delta_space()[i] = m_d[i];

			// compute origin
			m_cctkGH->cctk_origin_space()[i] = -0.5 * (m_cctkGH->cctk_gsh()[i] - 1 -
													   m_avoidOrigin[i] *
													   m_cctkGH->cctk_gsh()[i] % 2) *
				m_cctkGH->cctk_delta_space()[i];
		}
	}  else {
		throw std::invalid_argument("Unknown Grid Type " + m_gridType);
	}

	// apply symmetry
	setupSymmetry();
}

void ParParser::proceedTime(void)
{
	CCTK_REAL delta_time = 0.0;
	CCTK_REAL min, sdim;

	// get type and parameters
	GET(time::timestep_method, std::string, m_timeMethod);
	GET(time::dtfac, CCTK_REAL, m_dtfac);
	GET(time::courant_fac, CCTK_REAL, m_courant_fac);

	// compute
	if (equals(m_timeMethod, "given")) {
		CGETANDSET(timestep, CCTK_REAL, cctk_delta_time);
	} else if (equals(m_timeMethod, "courant_static")) {
		// dt = dtfac * min (dx^i)
		min = m_cctkGH->min_cctk_delta_space();
		delta_time = m_dtfac * min;
	} else if (equals(m_timeMethod, "courant_speed")) { // FIXME:
		// dt = courant_fac * min(dx^i) / courant_wave_speed / sqrt(dim)
		min = m_cctkGH->min_cctk_delta_space();
		sdim = sqrt(m_cctkGH->cctk_dim());
		delta_time = m_courant_fac * min / m_courant_speed / sdim;
	} else if (equals(m_timeMethod, "courant_time")) {  // FIXME:
		// dt = courant_fac * courant_min_time / sqrt(dim)
		sdim = sqrt(m_cctkGH->cctk_dim());
		delta_time = m_courant_fac * m_courant_min_time / sdim;
	} else {
		throw std::invalid_argument("Unknown Time Method " + m_timeMethod);
	}

	// finally set it
	m_cctkGH->cctk_delta_time(delta_time);
}

void ParParser::prepareValues(void)
{
	for (std::map<std::string, std::string>::iterator it = m_parMap.begin();
		 it != m_parMap.end(); ++it)
	{
		// remove \"\"
		boost::algorithm::erase_all(it->second, "\"");

		// trim value
		boost::algorithm::trim(it->second);

		// boolean: yes -> 1, no -> 0
		if (equals(it->second, "yes") || equals(it->second, "y") ||
			equals(it->second, "true") || equals(it->second, "t"))
		{
			it->second = "1";
		}
		if (equals(it->second, "no") || equals(it->second, "n") ||
			equals(it->second, "false") || equals(it->second, "f"))
		{
			it->second = "0";
		}
	}
}

void ParParser::parseLine(const std::string& line)
{
	boost::regex comment("^\\s*(#|!)", boost::regex::perl | boost::regex::icase);
	boost::regex empty("^\\s*$", boost::regex::perl | boost::regex::icase);
	boost::regex parameter("^\\s*(\\w+::\\w+|ActiveThorns)\\s*=\\s*(.*)$",
						   boost::regex::perl | boost::regex::icase);
	boost::smatch token;

	// check comment
	if (boost::regex_search(line, comment))
		return;
	// check empty
	if (boost::regex_search(line, empty))
		return;
	// parse line
	if (boost::regex_search(line, token, parameter)) {
		std::string implname = token[1];
		std::string value    = token[2];

		// parameters and values are case independent
		boost::algorithm::to_lower(implname);

		// save pair
		m_parMap[implname] = value;
	} else {
		throw std::invalid_argument("syntax error in line: \"" + line + "\"");
	}
}

void ParParser::parse()
{
	std::string line;
	std::ifstream parFile;

	if (!m_file)
		throw std::invalid_argument("No Parameter file given!");

	parFile.open(m_file);
	if (parFile.fail()) {
		std::string errMsg = "Bad Parameter file \"";
		errMsg += std::string(m_file);
		errMsg += "\". Is the path correct?";
		throw std::invalid_argument(errMsg);
	}

	while (!parFile.eof()) {
		// get line
		getline(parFile, line);
		// parse it
		parseLine(line);
	}

	parFile.close();

	// prepare for further processing
	prepareValues();

	// init m_cctkGH
	proceedCactus();
	proceedPUGH();
	proceedCartGrid();
	proceedTime();

	// setup thorn specific parameters
	SETUPTHORNPARAMETERS;

	m_parsed = true;
}
