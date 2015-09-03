/*!
 *  \file GelocateTelemetry.h
 *  \brief Information needed to locate the gimbals imagery on a map.
 *
 *  This module defines the GeolocateTelemetry_t structure which gives all the
 *  information needed to project the gimbals line of sight (typically until it
 *  intersects a terrain model). In addition this module gives the necessary
 *  functions to encode/decode this information to/from an OrionPacket. Note
 *  that the GEOLOCATE_TELEMETRY packet encodes the minimum amount of
 *  information; however the structure contains the position, velocity, and
 *  attitude data in multiple redundant forms, for the convenience of anyone
 *  who receives this data. The DecodeGeolocateTelemetry() function fills out
 *  the redundant data.
 */

#ifndef GEOLOCATETELEMETRY_H_
#define GEOLOCATETELEMETRY_H_

#include "earthposition.h"
#include "quaternion.h"
#include "Constants.h"
#include "OrionPublicPacket.h"
#include "OrionPublicPacketShim.h"

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

//! The information needed to determine location of gimbal image
typedef struct
{
    // The basic gelocation data that is transmitted and received in the packet
    GeolocateTelemetryCore_t base;

	// Data below this point are not transmitted but instead are constructed from what is above

	//! Year of the date
	UInt16 Year;

	//! Month of the year, Jan == 1, Dec == 12
	UInt8  Month;

	//! Day of the month, from 1 to 31
	UInt8  Day;

	//! Hour of the day, from 0 to 23
	UInt8  Hour;

	//! Minute of the hour, from 0 to 59
	UInt8  Minute;

	//! Second of the minute, from 0 to 59
	UInt8  Second;

	//! Trigonometric information about the LLA position
	llaTrig_t llaTrig;

	//! Position in ECEF meters
	double posECEF[NECEF];

	//! Velocity in ECEF meters per second
	float velECEF[NECEF];

	//! Euler attitude of the gimbal (roll, pitch, yaw) in radians
	float gimbalEuler[NUM_AXES];

    //! The DCM of the gimbal (body to nav NED)
	structAllocateDCM(gimbalDcm);

    //! Quaternion attitude of the camera (body to nav NED)
	float cameraQuat[NQUATERNION];

	//! Euler attitude of the camera (roll, pitch, yaw) in radians
	float cameraEuler[NUM_AXES];

    //! The DCM of the camera (body to nav NED)
	structAllocateDCM(cameraDcm);

	//! Slant range to target in meters
	float slantRange;

}GeolocateTelemetry_t;

//! Create a GeolocateTelemetry packet
void FormGeolocateTelemetry(OrionPkt_t *pPkt, const GeolocateTelemetry_t *pGeo);

//! Decode a GeolocateTelemetry packet
BOOL DecodeGeolocateTelemetry(const OrionPkt_t *pPkt, GeolocateTelemetry_t *pGeo);

//! Offset an image location according to a user click
BOOL offsetImageLocation(const GeolocateTelemetry_t *geo, const double imagePosLLA[NLLA], float ydev, float zdev, double newPosLLA[NLLA]);

//! Use GPS time information to compute the Gregorian calendar date.
void computeDateFromWeekAndItow(uint16_t week, uint32_t itow, uint16_t* pyear, uint8_t* pmonth, uint8_t* pday);

//! Use Gregorian date information to compute GPS style time information.
void computeWeekAndItow(uint16_t year, uint8_t month, uint8_t day, uint8_t hours, uint8_t minutes, uint8_t seconds, int16_t milliseconds, uint16_t* pweek, uint32_t* pitow);

//! Test the date conversion logic
int testDateConversion(void);

#ifdef __cplusplus
}
#endif // __cplusplus

#endif // GEOLOCATETELEMETRY_H_
