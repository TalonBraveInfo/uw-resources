class SHover extends SVehicle
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

	// SHover interface.
	virtual void PackState();
#endif
}

var		vector				FrontThrustOffset;
var		vector				RearThrustOffset;

var()	float				HoverSoftness;
var()	float				HoverPenScale;
var()	float				HoverCheckDist;

var()	float				UprightStiffness;
var()	float				UprightDamping;

var()	float				MaxThrust;
var()	float				MaxSteerTorque;
var()	float				ForwardDampFactor;
var()	float				LateralDampFactor;
var()	float				SteerDampFactor;
var()	float				PitchTorqueFactor;
var()	float				PitchDampFactor;
var()	float				BankTorqueFactor;
var()	float				BankDampFactor;

var()	float				StopThreshold;

// MPH meter
var		material			MPHMeterMaterial;
var()	float				MPHMeterPosX;
var()	float				MPHMeterPosY;
var()	float				MPHMeterScale;
var()	float				MPHMeterSizeY;

// Internal
var		float				BikeMPH;

var		float				OutputThrust;
var		float				OutputTurn;

// Replicated
struct native HoverbikeState
{
	var KRBVec				ChassisPosition;
	var Quat				ChassisQuaternion;
	var KRBVec				ChassisLinVel;
	var KRBVec				ChassisAngVel;

	var float				ServerThrust;
	var	float				ServerTurn;

	var int					bNewState;
};

var		HoverbikeState		BikeState;
var		KRigidBodyState		ChassisState;
var		bool				bNewBikeState;

replication
{
	unreliable if(Role == ROLE_Authority)
		BikeState;
}

simulated event bool KUpdateState(out KRigidBodyState newState)
{
	// This should never get called on the server - but just in case!
	if(Role == ROLE_Authority || !bNewBikeState)
		return false;

	newState = ChassisState;
	bNewBikeState = false;

	return true;
	//return false;
}

simulated function PostNetBeginPlay()
{
	local vector RotX, RotY, RotZ;
	local KarmaParams kp;
	local KRepulsor rep;

    GetAxes(Rotation,RotX,RotY,RotZ);

	// Spawn and assign 'repulsors' to hold bike off the ground
	kp = KarmaParams(KParams);
	kp.Repulsors.Length = 2;

	rep = spawn(class'KRepulsor', self,, Location + FrontThrustOffset.X * RotX + FrontThrustOffset.Y * RotY + FrontThrustOffset.Z * RotZ);
	rep.SetBase(self);
	kp.Repulsors[0] = rep;

	rep = spawn(class'KRepulsor', self,, Location + RearThrustOffset.X * RotX + RearThrustOffset.Y * RotY + RearThrustOffset.Z * RotZ);
	rep.SetBase(self);
	kp.Repulsors[1] = rep;


    Super.PostNetBeginPlay();
}

simulated event Destroyed()
{
	local KarmaParams kp;

	// Destroy repulsors
	kp = KarmaParams(KParams);
	kp.Repulsors[0].Destroy();
	kp.Repulsors[1].Destroy();

	Super.Destroyed();
}

simulated event SVehicleUpdateParams()
{
	local KarmaParams kp;

	Super.SVehicleUpdateParams();

	kp = KarmaParams(KParams);

	kp.Repulsors[0].Softness = HoverSoftness;
	kp.Repulsors[0].PenScale = HoverPenScale;
	kp.Repulsors[0].CheckDist = HoverCheckDist;

	kp.Repulsors[1].Softness = HoverSoftness;
	kp.Repulsors[1].PenScale = HoverPenScale;
	kp.Repulsors[1].CheckDist = HoverCheckDist;

	KSetStayUprightParams( UprightStiffness, UprightDamping );
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
	Canvas.SetPos(MPHMeterPosX * Canvas.ClipX, MPHMeterPosY * Canvas.ClipY);
	Canvas.DrawTileStretched(MPHMeterMaterial, (BikeMPH/MPHMeterScale) * Canvas.ClipX, MPHMeterSizeY * Canvas.ClipY);

	Canvas.SetPos( MPHMeterPosX * Canvas.ClipX, (MPHMeterSizeY + MPHMeterPosY) * Canvas.ClipY + YL );
    Canvas.Font = class'HUD'.Static.GetConsoleFont(Canvas);
	Canvas.DrawText(BikeMPH);
}

defaultproperties
{
	bSpecialHUD=true

	MPHMeterMaterial=Material'GUIContent.BorderBoxD'
	MPHMeterPosX=0.01
	MPHMeterPosY=0.9
	MPHMeterScale=70.0
	MPHMeterSizeY=0.05
}