class SHelicopter extends SVehicle
	abstract
	native;

cpptext
{
#ifdef WITH_KARMA
	// Actor interface.
	virtual UBOOL Tick(FLOAT DeltaTime, enum ELevelTick TickType);
	virtual void PostNetReceive();

	// SVehicle interface.
	virtual void UpdateVehicle(FLOAT DeltaTime);
	virtual void physKarma(FLOAT DeltaTime);

	// SHelicopter interface.
	virtual void PackState();
#endif
}

var()	float				UprightStiffness;
var()	float				UprightDamping;

var()	float				LongDamping;
var()	float				LatDamping;
var()	float				UpDamping;

var()	float				TurnTorqueFactor;
var()	float				TurnTorqueMax;
var()	float				TurnDamping;
var()	float				MaxYawRate;

var()	float				PitchTorqueMax;
var()	float				PitchDamping;

var()	float				RollTorqueMax;
var()	float				RollDamping;

var()	float				RotorSpeedAccelRateMax;	// The max rate at which the rotations per second of rotor increase per second which scaled by user input
var()	float				RoterSpeedDecelRate;	// The rate at which the rotation per second of the rotor decrease per second if no button is pressed.
var()	float				RotorSpeedForceFactor;	// Force per (rotation per second) of the the main rotor
var()	float				RotorSpeedIdle;			// Idle speed of Rotor when in helicopter in rotations per second
var()	float				RotorSpeedMax;			// Max speed of Rotor in rotations per second



//struct native HelicopterRotors
//{
//	var		name				RotorBoneName;			// Name of the main rotor bone
//	var		EAxis				RotorBoneAxis;			// Axis of rotation for the main rotor bone
//	var		float				RotorBoneSpeedScale;	// Scale from RotorSpeed to bone rotation speed
//	var		float				MaxRotorSpeed;			// The max rotor speed
//	var		float				RotorBoneRotation;		// Current RotorBoneRotation;
//};
//
//var()	array<HelicopterRotors>		Rotors;					// The rotors for this helicopter

var()	name				RotorBoneName;			// Name of the main rotor bone
var()	EAxis				RotorBoneAxis;			// Axis of rotation for the main rotor bone
var()	float				RotorBoneSpeedScale;	// Scale from RotorSpeed to bone rotation speed
var()	float				RotorBoneSpeedMax;		// The max rotor speed
var		float				RotorBoneRotation;		// Current RotorBoneRotation;


// MPH meter
var		material			MPHMeterMaterial;
var()	float				MPHMeterPosX;
var()	float				MPHMeterPosY;
var()	float				MPHMeterScale;
var()	float				MPHMeterSizeY;

// Internal
var		float				RotorSpeed;				// The speed of the rotor in rotation per second



var		float				CopterMPH;

var		float				TargetHeading;
var		float				TargetPitch;

var		float				OutputThrust;
var		float				OutputStrafe;
var		float				OutputRise;
var		bool				bFollowLookDir;

// Replicated
struct native HelicopterState
{
	var KRBVec				ChassisPosition;
	var Quat				ChassisQuaternion;
	var KRBVec				ChassisLinVel;
	var KRBVec				ChassisAngVel;

	var float				ServerThrust;
	var	float				ServerStrafe;
	var	float				ServerRise;

	var int					bNewState;
};

var		HelicopterState		HeliState;
var		KRigidBodyState		ChassisState;
var		bool				bNewCopterState;

replication
{
	unreliable if(Role == ROLE_Authority)
		HeliState;
}

simulated event bool KUpdateState(out KRigidBodyState newState)
{
	// This should never get called on the server - but just in case!
	if(Role == ROLE_Authority || !bNewCopterState)
		return false;

	newState = ChassisState;
	bNewCopterState = false;

	return true;
	//return false;
}



simulated event SVehicleUpdateParams()
{
	Super.SVehicleUpdateParams();

	KSetStayUprightParams( UprightStiffness, UprightDamping );
}

simulated function bool SpecialCalcView(out actor ViewActor, out vector CameraLocation, out rotator CameraRotation )
{
	local vector CamLookAt, HitLocation, HitNormal, OffsetVector;
	local PlayerController pc;

	pc = PlayerController(Controller);

	// Only do this mode we have a playercontroller viewing this vehicle
	if(pc == None || pc.ViewTarget != self)
		return false;

	if(pc.bBehindView) ///// THIRD PERSON ///////
	{
		ViewActor = self;
		CamLookAt = Location + (TPCamLookat >> Rotation); 

		OffsetVector = vect(0, 0, 0);
		OffsetVector.X = -1.0 * TPCamDistance;

		CameraLocation = CamLookAt + (OffsetVector >> CameraRotation);

		if( Trace( HitLocation, HitNormal, CameraLocation, CamLookAt, false, vect(10, 10, 10) ) != None )
		{
			CameraLocation = HitLocation;
		}

		bOwnerNoSee = false;

		if(bDrawDriverInTP)
			Driver.bOwnerNoSee = false;
		else
			Driver.bOwnerNoSee = true;
	}
	else ////// FIRST PERSON //////
	{
		ViewActor = self;

		CameraLocation = Location + (FPCamPos >> Rotation);

		if(bDrawMeshInFP)
			bOwnerNoSee = false;
		else
			bOwnerNoSee = true;

		Driver.bOwnerNoSee = true; // In first person, dont draw the driver
	}

	return true;
}

function DrawHUD(Canvas Canvas)
{
	local Color WhiteColor;
	local float XL, YL;

	Super.DrawHUD(Canvas);

	WhiteColor = class'Canvas'.Static.MakeColor(255,255,255);
	Canvas.DrawColor = WhiteColor;

	Canvas.Style = ERenderStyle.STY_Normal;
	Canvas.StrLen("TEST", XL, YL);

	// Draw rev meter
	//Canvas.SetPos(MPHMeterPosX * Canvas.ClipX, MPHMeterPosY * Canvas.ClipY);
	//Canvas.DrawTileStretched(MPHMeterMaterial, (CopterMPH/MPHMeterScale) * Canvas.ClipX, MPHMeterSizeY * Canvas.ClipY);

	//Canvas.SetPos( MPHMeterPosX * Canvas.ClipX, (MPHMeterSizeY + MPHMeterPosY) * Canvas.ClipY + YL );
 //   Canvas.Font = class'HUD'.Static.GetConsoleFont(Canvas);
	//Canvas.DrawText(CopterMPH);
	Canvas.SetPos(MPHMeterPosX * Canvas.ClipX, MPHMeterPosY * Canvas.ClipY);
	Canvas.DrawTileStretched(MPHMeterMaterial, (RotorSpeed/MPHMeterScale) * Canvas.ClipX, MPHMeterSizeY * Canvas.ClipY);

	Canvas.SetPos( MPHMeterPosX * Canvas.ClipX, (MPHMeterSizeY + MPHMeterPosY) * Canvas.ClipY + YL );
    Canvas.Font = class'HUD'.Static.GetConsoleFont(Canvas);
	Canvas.DrawText(CopterMPH);
}

defaultproperties
{
	bSpecialHUD=true

	bZeroPCRotOnEntry=false

	MPHMeterMaterial=Material'InterfaceContent.BorderBoxD'
	MPHMeterPosX=0.01
	MPHMeterPosY=0.9
	MPHMeterScale=70.0
	MPHMeterSizeY=0.05
}