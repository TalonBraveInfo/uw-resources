/*=============================================================================
	SHover.cpp:
	Copyright 1997-2003 Epic Games, Inc. All Rights Reserved.

Revision history:
	* Created by James Golding
=============================================================================*/

#include "VehiclesPrivate.h"

#ifdef WITH_KARMA

// Calculate forces for thrust/turning etc. and apply them.
void ASHover::UpdateVehicle(FLOAT DeltaTime)
{
	guard(ASHover::UpdateVehicle);

	BikeMPH = 0.0f;

	// Dont go adding forces if vehicle is asleep.
	if( !KIsAwake() )
		return;

	// Calc up (z), right(y) and forward (x) vectors
	FCoords Coords = GMath.UnitCoords / Rotation;
	FVector DirX = Coords.XAxis;
	FVector DirY = Coords.YAxis;
	FVector DirZ = Coords.ZAxis;

	// Get body angular velocity (JTODO: Add AngularVelocity to Actor!)
	FKRigidBodyState rbState;
	KGetRigidBodyState(&rbState);
	FVector angVel(rbState.AngVel.X, rbState.AngVel.Y, rbState.AngVel.Z);

	// Zero force/torque accumulation.
	FVector Force(0.0f, 0.0f, 0.0f);
	FVector Torque(0.0f, 0.0f, 0.0f);

	// Thrust
	Force += (OutputThrust * MaxThrust * DirX);

	// Pitching torque
	Torque += (PitchTorqueFactor * OutputThrust * DirY);

	// Pitch damping
	FLOAT VelMag = angVel | DirY;
	Torque += (-1.0f * VelMag * PitchDampFactor * DirY);

	// Forward damping
	FLOAT ForwardVelMag = Velocity | DirX;
	Force += (-1.0f * ForwardVelMag * ForwardDampFactor * DirX);

	// Invert steering when we are going backwards
	FLOAT UseTurn;
	if( ForwardVelMag < -1.0f * StopThreshold )
		UseTurn = -1.0f * OutputTurn;
	else
		UseTurn = OutputTurn;

	// Lateral damping
	VelMag = Velocity | DirY;
	Force += (-1.0f * VelMag * LateralDampFactor * DirY);

	// Turn damping
	VelMag = angVel | DirZ;
	Torque += (-1.0f * SteerDampFactor * VelMag * DirZ);
		
	// Steer Torque
	Torque += (-1.0f * MaxSteerTorque * UseTurn * DirZ);

	// Banking Torque
	Torque += (BankTorqueFactor * UseTurn * DirX);	

	// Bank (roll) Damping
	VelMag = angVel | DirX;
	Torque += (-1.0f * VelMag * BankDampFactor * DirX);

	// Apply force/torque to body.
	KAddForces(Force, Torque);

	/////// OUTPUT ////////

	// Set current bike speed. Convert from units per sec to miles per hour.
	BikeMPH = Abs( (ForwardVelMag * 3600.0f) / 140800.0f );

	unguard;
}

UBOOL ASHover::Tick(FLOAT DeltaTime, enum ELevelTick TickType)
{
	guard(ASHover::Tick);

	UBOOL TickDid = Super::Tick(DeltaTime, TickType);

    // If the server, process input and pack updated car info into struct.
    if(Role == ROLE_Authority)
	{
		OutputThrust = Throttle;
		OutputTurn = Steering;

		KWake(); // keep vehicle alive while driving

		PackState();
	}

	return TickDid;

	unguard;
}

void ASHover::PackState()
{
	guard(ASHover::PackState);

	if( !KIsAwake() )
		return;

	FKRigidBodyState RBState;
	KGetRigidBodyState(&RBState);

	BikeState.ChassisPosition = RBState.Position;
	BikeState.ChassisQuaternion = RBState.Quaternion;
	BikeState.ChassisLinVel = RBState.LinVel;
	BikeState.ChassisAngVel = RBState.AngVel;

	BikeState.ServerThrust = OutputThrust;
	BikeState.ServerTurn = OutputTurn;

	BikeState.bNewState = 1;
	bNetDirty = true;

	unguard;
}

// Deal with new infotmation about the arriving from the server
void ASHover::PostNetReceive()
{
	guard(ASHover::PostNetReceive);

	Super::PostNetReceive();

	if( BikeState.bNewState == 0 )
		return;

	ChassisState.Position = BikeState.ChassisPosition;
	ChassisState.Quaternion = BikeState.ChassisQuaternion;
	ChassisState.LinVel = BikeState.ChassisLinVel;
	ChassisState.AngVel = BikeState.ChassisAngVel;
	bNewBikeState = true;

	OutputThrust = BikeState.ServerThrust;
	OutputTurn = BikeState.ServerTurn;

	BikeState.bNewState = 0;

	//KDrawRigidBodyState(BikeState.ChassisState, false);

	unguard;
}

#endif // WITH_KARMA

IMPLEMENT_CLASS(ASHover);
