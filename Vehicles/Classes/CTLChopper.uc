class CTLChopper extends SHelicopter;

defaultproperties
{
	Mesh=Mesh'COGChopperAsset.COG_Copter2'

	TPCamDistance=1000
	bDrawDriverInTP=false
	bDrawMeshInFP=true
	FPCamPos=(X=160,Y=0,Z=80)

	UprightStiffness=7.5
	UprightDamping=5

	LongDamping=0.03
	LatDamping=0.03
	UpDamping=0.03

	TurnTorqueFactor=350.0
	TurnTorqueMax=150.0
	TurnDamping=45.0
	MaxYawRate=2.0

	PitchTorqueMax=25.0
	PitchDamping=20.0

	RollTorqueMax=25.0
	RollDamping=20.0

	RotorSpeedAccelRateMax=160.0
	RoterSpeedDecelRate=0.0
    RotorSpeedForceFactor=1.0
    RotorSpeedIdle=20.0
    RotorSpeedMax=200.0

    RotorBoneName="Blades_1"
    RotorBoneAxis=AXIS_Y
    RotorBoneSpeedScale=3000.0
    RotorBoneSpeedMax=1000000.0

    MPHMeterScale=250.000000

	VehicleMass=4.0

	EntryPositions(0)=(X=0,Y=-165,Z=-80)

	ExitPositions(0)=(X=0,Y=-165,Z=100)
	ExitPositions(1)=(X=0,Y=165,Z=100)

    Begin Object Class=KarmaParamsRBFull Name=KParams0
		KStartEnabled=True
		KFriction=0.5
		KLinearDamping=0.0
		KAngularDamping=0.0
		bKNonSphericalInertia=True
        bHighDetailOnly=False
        bClientOnly=False
		bKDoubleTickRate=True
		bKStayUpright=True
		bKAllowRotate=True
		SafeTimeMode=KST_Always
		KInertiaTensor(0)=1.0
		KInertiaTensor(1)=0.0
		KInertiaTensor(2)=0.0
		KInertiaTensor(3)=3.0
		KInertiaTensor(4)=0.0
		KInertiaTensor(5)=3.5
		KCOMOffset=(X=0.0,Y=0.0,Z=0.0)
		KActorGravScale=1.0
        Name="KParams0"
    End Object
    KParams=KarmaParams'KParams0'
}