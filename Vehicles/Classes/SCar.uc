class SCar extends SVehicle
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

	// SCar interface.
	virtual void ProcessCarInput();
	virtual void ChangeGear(UBOOL bReverse);
	virtual void PackState();
#endif
}

// wheel params
var()	float			WheelSoftness;
var()	float			WheelPenScale;
var()	float			WheelRestitution;
var()	float			WheelAdhesion;
var()	float			WheelInertia;
var()	InterpCurve		WheelLongFrictionFunc;
var()	float			WheelLongSlip;
var()	InterpCurve		WheelLatSlipFunc;
var()	float			WheelLongFrictionScale;
var()	float			WheelLatFrictionScale;
var()	float			WheelHandbrakeSlip;
var()	float			WheelHandbrakeFriction;
var()	float			WheelSuspensionTravel;
var()	float			WheelSuspensionOffset;

var()	float			FTScale;
var()	float			ChassisTorqueScale;
var()	float			MinBrakeFriction;

var()	float			MaxSteerAngle; // degrees
var()	InterpCurve		TorqueCurve; // Engine output torque 
var()	float			GearRatios[5]; // 0 is reverse, 1-4 are forward
var()	float			TransRatio; // Other (constant) gearing
var()	float			ChangeUpPoint;
var()	float			ChangeDownPoint;
var()	float			LSDFactor;

var()	float			EngineBrakeFactor;
var()	float			EngineBrakeRPMScale;

var()	float			MaxBrakeTorque;
var()	float			SteerSpeed; // degrees per second

var()	float			StopThreshold;
var()	float			HandbrakeThresh;

var()	float			EngineInertia; // Pre-gear box engine inertia (racing flywheel etc.)

var()	float			IdleRPM;
var()	sound			IdleSound;
var()	float			EngineRPMSoundRange;

var()	name			SteerBoneName;
var()	EAxis			SteerBoneAxis;
var()	float			SteerBoneMaxAngle; // degrees

// Internal
var		float			OutputBrake;
var		float			OutputGas;
var		bool			OutputHandbrake;
var		int				Gear;

var		float			ForwardVel;
var		bool			bIsInverted;
var		bool			bIsDriving;
var		float			NumPoweredWheels;

var		float			TotalSpinVel;
var		float			EngineRPM;
var		float			CarMPH;
var		float			ActualSteering;

// Rev meter
var		material		RevMeterMaterial;
var()	float			RevMeterPosX;
var()	float			RevMeterPosY;
var()	float			RevMeterScale;
var()	float			RevMeterSizeY;


struct native SCarState
{
	var KRBVec				ChassisPosition;
	var Quat				ChassisQuaternion;
	var KRBVec				ChassisLinVel;
	var KRBVec				ChassisAngVel;

	var float				ServerHandbrake;
	var float				ServerBrake;
	var float				ServerGas;
	var int					ServerGear;
	var	float				ServerSteering;

	var int					bNewState; // bools inside structs == scary!
};

var		SCarState			CarState;
var		KRigidBodyState		ChassisState;
var		bool				bNewCarState;

replication
{
	unreliable if(Role == ROLE_Authority)
		CarState;
}
///////////////////////////////////////////
/////////////// CREATION //////////////////
///////////////////////////////////////////

simulated function PostNetBeginPlay()
{
	local int i;

	// Count the number of powered wheels on the car
	NumPoweredWheels = 0.0;
	for(i=0; i<Wheels.Length; i++)
	{
		NumPoweredWheels += 1.0;
	}


    Super.PostNetBeginPlay();
}

///////////////////////////////////////////
/////////////// NETWORKING ////////////////
///////////////////////////////////////////


simulated event bool KUpdateState(out KRigidBodyState newState)
{
	// This should never get called on the server - but just in case!
	if(Role == ROLE_Authority || !bNewCarState)
		return false;

	newState = ChassisState;
	bNewCarState = false;

	return true;
	//return false;
}

///////////////////////////////////////////
////////////////// OTHER //////////////////
///////////////////////////////////////////

simulated event SVehicleUpdateParams()
{
	local int i;

	Super.SVehicleUpdateParams();

	for(i=0; i<Wheels.Length; i++)
	{
		Wheels[i].Softness = WheelSoftness;
		Wheels[i].PenScale = WheelPenScale;
		Wheels[i].Restitution = WheelRestitution;
		Wheels[i].Adhesion = WheelAdhesion;
		Wheels[i].WheelInertia = WheelInertia;
		Wheels[i].LongFrictionFunc = WheelLongFrictionFunc;
		Wheels[i].LongSlip = WheelLongSlip;
		Wheels[i].LatSlipFunc = WheelLatSlipFunc;
		Wheels[i].HandbrakeSlipFactor = WheelHandbrakeSlip;
		Wheels[i].HandbrakeFrictionFactor = WheelHandbrakeFriction;
		Wheels[i].SuspensionTravel = WheelSuspensionTravel;
		Wheels[i].SuspensionOffset = WheelSuspensionOffset;
	}
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
	Canvas.SetPos(RevMeterPosX * Canvas.ClipX, RevMeterPosY * Canvas.ClipY);
	Canvas.DrawTileStretched(RevMeterMaterial, ((IdleRPM+EngineRPM)/RevMeterScale) * Canvas.ClipX, RevMeterSizeY * Canvas.ClipY);

	Canvas.SetPos( RevMeterPosX * Canvas.ClipX, (RevMeterSizeY + RevMeterPosY) * Canvas.ClipY + YL );
    Canvas.Font = class'HUD'.Static.GetConsoleFont(Canvas);
	Canvas.DrawText(Gear@CarMPH@IdleRPM+EngineRPM);
}

event KDriverEnter(Pawn p)
{
	Super.KDriverEnter(p);

	AmbientSound = IdleSound;
}

event bool KDriverLeave(bool bForceLeave)
{
	// If we succesfully got out of the car, turn off the engine sound.
	if( Super.KDriverLeave(bForceLeave) )
	{
		AmbientSound = None;	
		return true;
	}
	else
		return false;
}


defaultproperties
{
	bSpecialHUD=true

	RevMeterMaterial=Material'GUIContent.BorderBoxD'
	RevMeterPosX=0.01
	RevMeterPosY=0.9
	RevMeterScale=4000.0
	RevMeterSizeY=0.05
}