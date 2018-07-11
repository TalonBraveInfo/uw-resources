/*=============================================================================
	SHelicopter.cpp:
	Copyright 1997-2003 Epic Games, Inc. All Rights Reserved.

Revision history:
	* Created by Chris Linder
=============================================================================*/

#include "VehiclesPrivate.h"

#ifdef WITH_KARMA

static inline float HeadingAngle(FVector dir)
{
	FLOAT angle = appAcos(dir.X);

	if(dir.Y < 0.0f)
		angle *= -1.0;

	return angle;
}

static inline float FindDeltaAngle(FLOAT a1, FLOAT a2)
{
	FLOAT delta = a2 - a1;

	if(delta > PI)
		delta = delta - (PI * 2.0f);
	else if(delta < -PI)
		delta = delta + (PI * 2.0f);

	return delta;
}

static inline float UnwindHeading(FLOAT a)
{
	while(a > PI)
		a -= ((FLOAT)PI * 2.0f);

	while(a < -PI)
		a += ((FLOAT)PI * 2.0f);

	return a;
}

// Calculate forces for thrust/turning etc. and apply them.
void ASHelicopter::UpdateVehicle(FLOAT DeltaTime)
{
	guard(ASHelicopter::UpdateVehicle);

	CopterMPH = 0.0f;

	// Dont go adding forces if vehicle is asleep.
	if( !KIsAwake() )
		return;

	// Calc up (z), right(y) and forward (x) vectors
	FCoords Coords = GMath.UnitCoords / Rotation;
	FVector DirX = Coords.XAxis;
	FVector DirY = Coords.YAxis;
	FVector DirZ = Coords.ZAxis;

	// 'World plane' forward & right vectors ie. no z component.
	FVector Forward = DirX;
	Forward.Z = 0.0f;
	Forward.Normalize();

	FVector Right = DirY;
	Right.Z = 0.0f;
	Right.Normalize();

	FVector Up(0.0f, 0.0f, 1.0f);

	FLOAT ForwardVelMag = Velocity | DirX;
	FLOAT RightVelMag = Velocity | DirY;
	FLOAT UpVelMag = Velocity | DirZ;

	// Zero force/torque accumulation.
	FVector Force(0.0f, 0.0f, 0.0f);
	FVector Torque(0.0f, 0.0f, 0.0f);


	// Linear Damping
	Force -= LongDamping * ForwardVelMag * DirX;
	Force -= LatDamping * RightVelMag * DirY;
	Force -= UpDamping * UpVelMag * DirZ;


	// Main Rotor
	RotorSpeed -= (1.0f - Abs(OutputRise)) * DeltaTime * RoterSpeedDecelRate;
	RotorSpeed += OutputRise *               DeltaTime * RotorSpeedAccelRateMax;
	RotorSpeed = Clamp<FLOAT>( RotorSpeed, RotorSpeedIdle, RotorSpeedMax );

	FLOAT RotorForce = RotorSpeed * RotorSpeedForceFactor; //Force per (rotation per second)
	Force += RotorForce * DirZ;


	// Rotation

	if(Controller)
	{
		FVector LookDir = Controller->DesiredRotation.Vector();

		//// YAW - global axis /////

		// Project Look dir into z-plane
		FVector PlaneLookDir = LookDir;
		PlaneLookDir.Z = 0.0f;
		PlaneLookDir.Normalize();

		FLOAT CurrentHeading = HeadingAngle(Forward);
		FLOAT DesiredHeading = HeadingAngle(PlaneLookDir);

		// Move 'target heading' towards 'desired heading' as fast as MaxYawRate allows.
		FLOAT DeltaTargetHeading = FindDeltaAngle(TargetHeading, DesiredHeading);
		FLOAT MaxDeltaHeading = DeltaTime * MaxYawRate;
		DeltaTargetHeading = Clamp<FLOAT>(DeltaTargetHeading, -MaxDeltaHeading, MaxDeltaHeading);
		TargetHeading = UnwindHeading(TargetHeading + DeltaTargetHeading);
		
		// Then put a 'spring' on the copter to target heading.
		FLOAT DeltaHeading = FindDeltaAngle(CurrentHeading, TargetHeading);
		FLOAT TurnTorqueMag = (DeltaHeading / PI) * TurnTorqueFactor;
		TurnTorqueMag = Clamp<FLOAT>( TurnTorqueMag, -TurnTorqueMax, TurnTorqueMax );
		Torque += ( TurnTorqueMag * Up );


		//// ROLL /////
		Torque += ( OutputStrafe * RollTorqueMax * DirX );

		//// PITCH /////
		Torque += ( OutputThrust * PitchTorqueMax * DirY );
	}

	// Get body angular velocity (JTODO: Add AngularVelocity to Actor!)
	FKRigidBodyState rbState;
	KGetRigidBodyState(&rbState);
	FVector AngVel(rbState.AngVel.X, rbState.AngVel.Y, rbState.AngVel.Z);

	// Rotational Damping
	FVector RotDamping( AngVel.X * RollDamping, AngVel.Y * PitchDamping, AngVel.Z * TurnDamping);
	Torque -= RotDamping;

	// Apply force/torque to body.
	KAddForces(Force, Torque);


	/////// OUTPUT ////////

	// Set current bike speed. Convert from units per sec to miles per hour.
	CopterMPH = Abs( (ForwardVelMag * 3600.0f) / 140800.0f );

	unguard;
}

UBOOL ASHelicopter::Tick(FLOAT DeltaTime, enum ELevelTick TickType)
{
	guard(ASHelicopter::Tick);

	UBOOL TickDid = Super::Tick(DeltaTime, TickType);

    // If the server, process input and pack updated car info into struct.
    if(Role == ROLE_Authority)
	{
		if( Driver != NULL )
		{
			OutputThrust = Throttle;
			OutputStrafe = Steering;
			OutputRise = Rise;
			bFollowLookDir = true;

			KWake(); // keep vehicle alive while driving
		}
		else
		{
			OutputThrust = 0;
			OutputStrafe = 0;
			OutputRise = 0;

			bFollowLookDir = false;
		}

		PackState();
	}

	return TickDid;

	unguard;
}


void ASHelicopter::physKarma(FLOAT DeltaTime)
{
	Super::physKarma(DeltaTime);

	check(Mesh);
	USkeletalMesh* smesh = Cast<USkeletalMesh>(Mesh);
	check(smesh);

	USkeletalMeshInstance* inst = (USkeletalMeshInstance*)smesh->MeshGetInstance(this);
	check(inst);

	//for(int i = 0; i < Rotors.Num(); i++)
	//{

	//	// Rotate Rotor Mesh
	//	Rotors[i]->RotorBoneRotation += RotorSpeed * DeltaTime * Rotors[i]->RotorBoneSpeedScale;
	//	Rotors[i]->RotorBoneRotation = Clamp<FLOAT>( Rotors[i]->RotorBoneRotation, 0, Rotors[i]->MaxRotorSpeed );

	//	FRotator RotorRotator;
	//	if(Rotors[i]->RotorBoneAxis == AXIS_X)
	//		RotorRotator = FRotator(0, 0, Rotors[i]->RotorBoneRotation);
	//	else if(Rotors[i]->RotorBoneAxis == AXIS_Y)
	//		RotorRotator = FRotator(-Rotors[i]->RotorBoneRotation, 0, 0);
	//	else if(Rotors[i]->RotorBoneAxis == AXIS_Z)
	//		RotorRotator = FRotator(0, -Rotors[i]->RotorBoneRotation, 0);

	//	inst->SetBoneRotation(Rotors[i]->RotorBoneName, RotorRotator, 0, 1);
	//}

	// Rotate Rotor Mesh

	if( Driver != NULL )
	{
		RotorBoneRotation += Clamp<FLOAT>( RotorSpeed * DeltaTime * RotorBoneSpeedScale, 0, RotorBoneSpeedMax );

		FRotator RotorRotator;
		if(RotorBoneAxis == AXIS_X)
			RotorRotator = FRotator(0, 0, RotorBoneRotation);
		else if(RotorBoneAxis == AXIS_Y)
			RotorRotator = FRotator(-RotorBoneRotation, 0, 0);
		else if(RotorBoneAxis == AXIS_Z)
			RotorRotator = FRotator(0, -RotorBoneRotation, 0);

		inst->SetBoneRotation(RotorBoneName, RotorRotator, 0, 1);
	}
}


void ASHelicopter::PackState()
{
	guard(ASHelicopter::PackState);

	if( !KIsAwake() )
		return;

	FKRigidBodyState RBState;
	KGetRigidBodyState(&RBState);

	HeliState.ChassisPosition = RBState.Position;
	HeliState.ChassisQuaternion = RBState.Quaternion;
	HeliState.ChassisLinVel = RBState.LinVel;
	HeliState.ChassisAngVel = RBState.AngVel;

	HeliState.ServerThrust = OutputThrust;
	HeliState.ServerStrafe = OutputStrafe;
	HeliState.ServerRise = OutputRise;

	HeliState.bNewState = 1;
	bNetDirty = true;

	unguard;
}

// Deal with new infotmation about the arriving from the server
void ASHelicopter::PostNetReceive()
{
	guard(ASHelicopter::PostNetReceive);

	Super::PostNetReceive();

	if( HeliState.bNewState == 0 )
		return;

	ChassisState.Position = HeliState.ChassisPosition;
	ChassisState.Quaternion = HeliState.ChassisQuaternion;
	ChassisState.LinVel = HeliState.ChassisLinVel;
	ChassisState.AngVel = HeliState.ChassisAngVel;
	bNewCopterState = true;

	OutputThrust = HeliState.ServerThrust;
	OutputStrafe = HeliState.ServerStrafe;
	OutputRise = HeliState.ServerRise;

	HeliState.bNewState = 0;

	//KDrawRigidBodyState(HeliState.ChassisState, false);

	unguard;
}

#endif // WITH_KARMA

IMPLEMENT_CLASS(ASHelicopter);
