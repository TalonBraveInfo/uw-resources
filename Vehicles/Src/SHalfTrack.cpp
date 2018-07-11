/*=============================================================================
	SHalfTrack.cpp:
	Copyright 1997-2003 Epic Games, Inc. All Rights Reserved.

Revision history:
	* Created by James Golding
	* Updated by Michiel Hendriks for 3323
=============================================================================*/

#include "VehiclesPrivate.h"

#ifdef WITH_KARMA

void ASHalfTrack::UpdateVehicle(FLOAT DeltaTime)
{
	guard(ASHalfTrack::UpdateVehicle);

	/////////// STEERING ///////////

	FLOAT maxSteer = DeltaTime * SteerSpeed;
	FLOAT MaxSteerAngle = MaxSteerAngleCurve.Eval(Velocity.Size());
	FLOAT deltaSteer = (-Steering * MaxSteerAngle) - ActualSteering; // Amount we want to move (target - current)
	deltaSteer = Clamp<FLOAT>(deltaSteer, -maxSteer, maxSteer);
	ActualSteering += deltaSteer;

	/////////// ENGINE ///////////

	// Calculate torque at output of engine. Combination of throttle, current RPM and engine braaking.
	FLOAT EngineTorque = OutputGas * TorqueCurve.Eval( EngineRPM );
	FLOAT EngineBraking = (1.0f - OutputGas) * (EngineBrakeRPMScale*EngineRPM * EngineBrakeRPMScale*EngineRPM * EngineBrakeFactor);

	EngineTorque -= EngineBraking;

	// Ratio between 
	FLOAT EngineWheelRatio = GearRatios[Gear] * TransRatio;

	FLOAT TrackTotalInertia = 0;
	for(INT i=0; i<Wheels.Num(); i++)
	{
		USVehicleWheel* vw = Wheels(i);
		if(vw->bTrackWheel)
			TrackTotalInertia += vw->WheelInertia;
	}

	// Track Brakes.
	FLOAT LimitTrackBrakeTorque = ( Abs(TrackSpinRate) * TrackTotalInertia ) / DeltaTime; // Size of torque needed to completely stop tracks spinning.
	FLOAT TrackBrakeTorque = 0.0f;

	// Brake torque acts to stop tracks (ie against direction of motion)
	if(TrackSpinRate > 0.0f)
		TrackBrakeTorque = -OutputBrake * MaxTrackBrakeTorque;
	else
		TrackBrakeTorque = OutputBrake * MaxTrackBrakeTorque;

	TrackBrakeTorque = Clamp(TrackBrakeTorque, -LimitTrackBrakeTorque, LimitTrackBrakeTorque); // Never apply more than this!

	// Add to torque coming from engine.
	EngineTorque += TrackBrakeTorque;

	// Update track rate
	FLOAT TrackAcc = (EngineWheelRatio * EngineTorque) / TrackTotalInertia;
	TrackSpinRate += DeltaTime * TrackAcc;

	// Update RPM
	EngineRPM = TrackSpinRate / EngineWheelRatio;
	EngineRPM /= 2.0f * (FLOAT)PI; // revs per sec
	EngineRPM *= 60;
	EngineRPM = Max( EngineRPM, 0.01f ); // ensure always positive!
		
	// Do model for each wheel.
	for(INT i=0; i<Wheels.Num(); i++)
	{
		USVehicleWheel* vw = Wheels(i);

		/////////// LONGITUDINAL ///////////
		if(vw->bTrackWheel)
		{
			vw->DriveForce = 0.0f;
			vw->ChassisTorque = 0.0f;
			vw->LongFriction = WheelLongFrictionScale * vw->TireLoad;
			
			vw->SpinVel = TrackSpinRate;
			vw->TrackVel = vw->SpinVel * TrackLinRatio;
		}
		else
		{
			// Calculate Grip Torque : longitudinal force against ground * distance of action (radius of tyre)
			// LongFrictionFunc is assumed to be reflected for negative Slip Ratio
			FLOAT GripTorque = FTScale * vw->WheelRadius * vw->TireLoad * WheelLongFrictionScale * vw->LongFrictionFunc.Eval( Abs(vw->SlipVel) );
			if(vw->SlipVel < 0.0f)
				GripTorque *= -1.0f;

			// GripTorque can't be more than the torque needed to invert slip ratio.
			FLOAT TransInertia = (EngineInertia / Abs(GearRatios[Gear] * TransRatio)) + vw->WheelInertia;

			// Brake torque acts to stop wheels (ie against direction of motion)
			FLOAT BrakeTorque = 0.0f;

			if(vw->SpinVel > 0.0f)
				BrakeTorque = -OutputBrake * MaxBrakeTorque;
			else
				BrakeTorque = OutputBrake * MaxBrakeTorque;

			FLOAT LimitBrakeTorque = ( Abs(vw->SpinVel) * TransInertia ) / DeltaTime; // Size of torque needed to completely stop wheel spinning.
			BrakeTorque = Clamp(BrakeTorque, -LimitBrakeTorque, LimitBrakeTorque); // Never apply more than this!

			// Resultant torque at wheel : torque applied from engine + brakes + equal-and-opposite from tire-road interaction.
			FLOAT WheelTorque = BrakeTorque - GripTorque;

			// Resultant linear force applied to car. (GripTorque applied at road)
			FLOAT VehicleForce = GripTorque / (FTScale * vw->WheelRadius);

			// As the wheel torque is always opposing the direction of spin (ie braking) we use friction to apply it.
			vw->DriveForce = 0.0f;
			vw->LongFriction = Abs(VehicleForce) + (OutputBrake * MinBrakeFriction);

			// Calculate torque applied back to chassis
			vw->ChassisTorque = -1.0f * BrakeTorque * ChassisTorqueScale;

			// Calculate new wheel speed. 
			// The lower the gear ratio, the harder it is to accelerate the engine.
			FLOAT TransAcc = WheelTorque / TransInertia;
			vw->SpinVel += TransAcc * DeltaTime;

			// Make sure the wheel can't spin in the wrong direction for the current gear.
			if(Gear == 0 && vw->SpinVel > 0.0f)
				vw->SpinVel = 0.0f;
			else if(Gear > 0 && vw->SpinVel < 0.0f)
				vw->SpinVel = 0.0f;

		}

		/////////// LATERAL ///////////

		vw->LatFriction = WheelLatFrictionScale * vw->TireLoad;
		vw->LatSlip = vw->LatSlipFunc.Eval(vw->SpinVel);

		if(OutputHandbrake && vw->bHandbrakeWheel)
		{
			vw->LatFriction *= vw->HandbrakeFrictionFactor;
			vw->LatSlip *= vw->HandbrakeSlipFactor;
		}

		/////////// STEERING  ///////////

		// Pass on steering to wheels that want it.
		if(vw->SteerType == VST_Steered)
			vw->Steer = ActualSteering;
		else if(vw->SteerType == VST_Inverted)
			vw->Steer = -ActualSteering;
		else
			vw->Steer = 0.0f;
	}

	unguard;
}

#endif // WITH_KARMA

IMPLEMENT_CLASS(ASHalfTrack);
