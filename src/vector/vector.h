#ifndef _VECTOR_H_
#define _VECTOR_H_

#include <libflatarray/short_vec.hpp>

/**
 * Wrapper class for SoA variables to do a vector read.
 */
template<typename TYPE, int ARITY>
class VecRead
{
private:
	const TYPE *m_data;
public:
	VecRead(const TYPE *data) :
		m_data(data)
	{}
	inline
	LibFlatArray::short_vec<TYPE, ARITY> operator[] (int index)
	{
		LibFlatArray::short_vec<TYPE, ARITY> buf;
		// load vector
		buf = m_data + index;
		return buf;
	}
};

/**
 * Wrapper class for SoA variables to do a vector write.
 */
template<typename TYPE, int ARITY>
class VecWrite
{
private:
	TYPE *m_data;
	int m_index;
public:
	inline
	VecWrite(TYPE *data) :
		m_data(data), m_index(0)
	{}
	inline
	VecWrite& operator[] (int index)
	{
		// save index
		m_index = index;
		return *this;
	}
	inline
	VecWrite& operator= (const LibFlatArray::short_vec<TYPE, ARITY>& buf)
	{
		// store vector
		(m_data + m_index) << buf;
		return *this;
	}
};

/**
 * The following code does operator overloading for missing operators.
 */
template<typename TYPE, int ARITY>
inline
LibFlatArray::short_vec<TYPE, ARITY> operator* (TYPE scalar, const LibFlatArray::short_vec<TYPE, ARITY>& vec)
{
	return vec * scalar;
}

template<typename TYPE, int ARITY>
inline
LibFlatArray::short_vec<TYPE, ARITY> operator/ (TYPE scalar, const LibFlatArray::short_vec<TYPE, ARITY>& vec)
{
	LibFlatArray::short_vec<TYPE, ARITY> buf = scalar;
	buf /= vec;
	return buf;
}

#endif /* _VECTOR_H_ */
