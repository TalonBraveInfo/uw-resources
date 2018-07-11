// The difference between a half-track and a tank is how it steers...

class SHalfTrack extends SCar
	abstract
	native;

cpptext
{
#ifdef WITH_KARMA
	// SVehicle interface.
	virtual void UpdateVehicle(FLOAT DeltaTime);
#endif
}

// TRACK PARAMS
var()	float			TrackInertia;
var()	float			TrackLongSlip;
var()	InterpCurve		TrackLatSlipFunc;
var()	float			TrackLongFrictionScale;
var()	float			TrackLatFrictionScale;

var()	float			TrackLinRatio; // Ratio between TrackSpinRate and linear velocity of track.
var()	float			MaxTrackBrakeTorque;

// INTERNAL
var		float			TrackSpinRate;

simulated event SVehicleUpdateParams()
{
	local int i;

	// This sets parameters on all wheels
	Super.SVehicleUpdateParams();

	// We set different parameters for the tracked wheels.
	for(i=0; i<Wheels.Length; i++)
	{
		if(Wheels[i].bTrackWheel)
		{
			Wheels[i].WheelInertia = TrackInertia;
			Wheels[i].LongSlip = TrackLongSlip;
		}
	}
}

defaultproperties
{

}