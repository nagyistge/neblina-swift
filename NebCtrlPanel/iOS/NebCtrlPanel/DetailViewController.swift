//
//  DetailViewController.swift
//  Nebblina Control Panel
//
//  Created by Hoan Hoang on 2015-10-22.
//  Copyright © 2015 Hoan Hoang. All rights reserved.
//

import UIKit
import CoreBluetooth
import QuartzCore
import SceneKit

let MotionDataStream = Int32(1)
let Heading = Int32(2)

struct NebCmdItem {
	let SubSysId : Int32
	let	CmdId : Int32
	let Name : String
	let Actuator : Int
	let Text : String
}

let NebCmdList = [NebCmdItem] (arrayLiteral:
	NebCmdItem(SubSysId: NEB_CTRL_SUBSYS_DEBUG, CmdId: DEBUG_CMD_SET_DATAPORT, Name: "BLE Data Port", Actuator : 1, Text:""),
    NebCmdItem(SubSysId: NEB_CTRL_SUBSYS_DEBUG, CmdId: DEBUG_CMD_SET_DATAPORT, Name: "UART Data Port", Actuator : 1, Text:""),
    NebCmdItem(SubSysId: NEB_CTRL_SUBSYS_MOTION_ENG, CmdId: SetFusionType, Name: "Fusion 9 axis", Actuator : 1, Text:""),
    NebCmdItem(SubSysId: NEB_CTRL_SUBSYS_MOTION_ENG, CmdId: Quaternion, Name: "Quaternion Stream", Actuator : 1, Text:""),
    NebCmdItem(SubSysId: NEB_CTRL_SUBSYS_MOTION_ENG, CmdId: MAG_Data, Name: "Mag Stream", Actuator : 1, Text:""),
    NebCmdItem(SubSysId: NEB_CTRL_SUBSYS_MOTION_ENG, CmdId: IMU_Data, Name: "IMU Stream", Actuator : 1, Text:""),
    NebCmdItem(SubSysId: 0xf, CmdId: MotionDataStream, Name: "Motion data stream", Actuator : 1, Text:""),
    NebCmdItem(SubSysId: 0xf, CmdId: Heading, Name: "Heading", Actuator : 1, Text:""),
	NebCmdItem(SubSysId: NEB_CTRL_SUBSYS_MOTION_ENG, CmdId: LockHeadingRef, Name: "Lock Heading Ref.", Actuator : 1, Text:""),
	NebCmdItem(SubSysId: NEB_CTRL_SUBSYS_STORAGE, CmdId: FlashRecordStartStop, Name: "Flash Record", Actuator : 1, Text:""),
	NebCmdItem(SubSysId: NEB_CTRL_SUBSYS_STORAGE, CmdId: FlashPlaybackStartStop, Name: "Flash Playback", Actuator : 1, Text:""),
	NebCmdItem(SubSysId: NEB_CTRL_SUBSYS_LED, CmdId: LED_CMD_SET_VALUE, Name: "Set LED0 level", Actuator : 3, Text:""),
	NebCmdItem(SubSysId: NEB_CTRL_SUBSYS_LED, CmdId: LED_CMD_SET_VALUE, Name: "Set LED1 level", Actuator : 3, Text:""),
	NebCmdItem(SubSysId: NEB_CTRL_SUBSYS_LED, CmdId: LED_CMD_SET_VALUE, Name: "Set LED2", Actuator : 1, Text:""),
	NebCmdItem(SubSysId: NEB_CTRL_SUBSYS_EEPROM, CmdId: EEPROM_Read, Name: "EEPROM Read", Actuator : 2, Text:"Read"),
	NebCmdItem(SubSysId: NEB_CTRL_SUBSYS_POWERMGMT, CmdId: POWERMGMT_CMD_SET_CHARGE_CURRENT, Name: "Charge Current in mA", Actuator : 3, Text:""),
	NebCmdItem(SubSysId: NEB_CTRL_SUBSYS_STORAGE, CmdId: FlashEraseAll, Name: "Flash Erase All", Actuator : 1, Text:"")
)


//let CtrlName = [String](arrayLiteral:"Heading")//, "Test1", "Test2")

class DetailViewController: UIViewController, UITextFieldDelegate, CBPeripheralDelegate, NeblinaDelegate, SCNSceneRendererDelegate {

	var nebdev : Neblina? {
		didSet {
			nebdev!.delegate = self
		}
	}
	//let scene = SCNScene(named: "art.scnassets/Millennium_Falcon/Millennium_Falcon.dae") as SCNScene!
	//let scene = SCNScene(named: "art.scnassets/Arc-170_ship/Obj_Shaded/Arc170.dae")!
	let scene = SCNScene(named: "art.scnassets/ship.scn")!
	//let scene = SCNScene(named: "art.scnassets/E-TIE-I/E-TIE-I.3ds.obj")!
	//var textview = UITextView()

	
	//@IBOutlet weak var detailDescriptionLabel: UILabel!

	@IBOutlet weak var cmdView: UITableView!
	@IBOutlet weak var versionLabel: UILabel!
	@IBOutlet weak var label: UILabel!
	@IBOutlet weak var flashLabel: UILabel!
	@IBOutlet weak var dumpLabel: UILabel!
	
	//var eulerAngles = SCNVector3(x: 0,y:0,z:0)
	var ship : SCNNode! //= scene.rootNode.childNodeWithName("ship", recursively: true)!
	let max_count = Int16(15)
	var prevTimeStamp = UInt32(0)
	var cnt = Int16(15)
	var xf = Int16(0)
	var yf = Int16(0)
	var zf = Int16(0)
	var heading = Bool(false)
	var flashEraseProgress = Bool(false)
	var PaketCnt = UInt32(0)
	var dropCnt = UInt32(0)
	var curDownloadSession = UInt16(0xFFFF)
	var curDownloadOffset = UInt32(0)
	
/*	var detailItem: Neblina? {
		didSet {
		    // Update the view.
		    //self.configureView()
			//detailItem!.delegate = self
			nebdev = detailItem
			nebdev.setPeripheral(detailItem!.id, peripheral : detailItem!.peripheral)
			nebdev.delegate = self
		}
	}*/
	
	func configureView() {
		// Update the user interface for the detail item.
		if self.nebdev != nil {
		    //if let label = self.consoleTextView {
	        //label.text = detail.description
		   // }
		}
	}

	func getCmdIdx(_ subsysId : Int32, cmdId : Int32) -> Int {
		for (idx, item) in NebCmdList.enumerated() {
			if (item.SubSysId == subsysId && item.CmdId == cmdId) {
				return idx
			}
		}
		
		return -1
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		
		cnt = max_count
		//textview = self.view.viewWithTag(3) as! UITextView
		
		// create a new scene
		//scene = SCNScene(named: "art.scnassets/ship.scn")!
		
		//scene = SCNScene(named: "art.scnassets/Arc-170_ship/Obj_Shaded/Arc170.obj")
		
		// create and add a camera to the scene
		let cameraNode = SCNNode()
		cameraNode.camera = SCNCamera()
		scene.rootNode.addChildNode(cameraNode)
		
		// place the camera
		cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)
		//cameraNode.position = SCNVector3(x: 0, y: 15, z: 0)
		//cameraNode.rotation = SCNVector4(0, 0, 1, GLKMathDegreesToRadians(-180))
		//cameraNode.rotation = SCNVector3(x:
		// create and add a light to the scene
		let lightNode = SCNNode()
		lightNode.light = SCNLight()
		lightNode.light!.type = SCNLight.LightType.omni
		lightNode.position = SCNVector3(x: 0, y: 10, z: 50)
		scene.rootNode.addChildNode(lightNode)
		
		// create and add an ambient light to the scene
		let ambientLightNode = SCNNode()
		ambientLightNode.light = SCNLight()
		ambientLightNode.light!.type = SCNLight.LightType.ambient
		ambientLightNode.light!.color = UIColor.darkGray
		scene.rootNode.addChildNode(ambientLightNode)
		
		
		// retrieve the ship node
		
//		ship = scene.rootNode.childNodeWithName("MillenniumFalconTop", recursively: true)!
//		ship = scene.rootNode.childNodeWithName("ARC_170_LEE_RAY_polySurface1394376_2_2", recursively: true)!
		ship = scene.rootNode.childNode(withName: "ship", recursively: true)!
//		ship = scene.rootNode.childNodeWithName("MDL Obj", recursively: true)!
		ship.eulerAngles = SCNVector3Make(GLKMathDegreesToRadians(90), 0, GLKMathDegreesToRadians(180))
		//ship.rotation = SCNVector4(1, 0, 0, GLKMathDegreesToRadians(90))
		//print("1 - \(ship)")
		// animate the 3d object
		//ship.runAction(SCNAction.repeatActionForever(SCNAction.rotateByX(0, y: 2, z: 0, duration: 1)))
		//ship.runAction(SCNAction.rotateToX(CGFloat(eulerAngles.x), y: CGFloat(eulerAngles.y), z: CGFloat(eulerAngles.z), duration:1 ))// 10, y: 0.0, z: 0.0, duration: 1))
		
		// retrieve the SCNView
		let scnView = self.view.subviews[0] as! SCNView
		
		// set the scene to the view
		scnView.scene = scene
		
		// allows the user to manipulate the camera
		scnView.allowsCameraControl = true
		
		// show statistics such as fps and timing information
		scnView.showsStatistics = true
		
		// configure the view
		scnView.backgroundColor = UIColor.black
		
		// add a tap gesture recognizer
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(DetailViewController.handleTap(_:)))
		scnView.addGestureRecognizer(tapGesture)
		//scnView.preferredFramesPerSecond = 60
		
	}
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool // called when 'return' key pressed. return NO to ignore.
	{
		textField.resignFirstResponder()

		var value = UInt16(textField.text!)
		let idx = cmdView.indexPath(for: textField.superview!.superview as! UITableViewCell)
		let row = ((idx as NSIndexPath?)?.row)! as Int
		if (value == nil) {
			value = 0
		}
		switch (NebCmdList[row].SubSysId) {
			case NEB_CTRL_SUBSYS_LED:
				let i = getCmdIdx(NEB_CTRL_SUBSYS_LED,  cmdId: LED_CMD_SET_VALUE)
				nebdev!.setLed(UInt8(row - i), Value: UInt8(value!))
			
				break
			case NEB_CTRL_SUBSYS_POWERMGMT:
				nebdev!.setBatteryChargeCurrent(value!)
				break
			default:
				break
		}

		return true;
	}
	
	func handleTap(_ gestureRecognize: UIGestureRecognizer) {
		// retrieve the SCNView
		let scnView = self.view.subviews[0] as! SCNView
		
		// check what nodes are tapped
		let p = gestureRecognize.location(in: scnView)
		let hitResults = scnView.hitTest(p, options: nil)
		// check that we clicked on at least one object
		if hitResults.count > 0 {
			// retrieved the first clicked object
			let result: AnyObject! = hitResults[0]
			
			// get its material
			let material = result.node!.geometry!.firstMaterial!
			
			// highlight it
			SCNTransaction.begin()
			SCNTransaction.animationDuration = 0.5
			
			// on completion - unhighlight
			/*SCNTransaction.completionBlock {
				SCNTransaction.begin()
				SCNTransaction.animationDuration = 0.5
				
				material.emission.contents = UIColor.black
				
				SCNTransaction.commit()
			}
			*/
			material.emission.contents = UIColor.red
			
			SCNTransaction.commit()
		}
		
	}
	

	override var shouldAutorotate : Bool {
		return true
	}
	
	override var prefersStatusBarHidden : Bool {
		return true
	}
	
	override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
		if UIDevice.current.userInterfaceIdiom == .phone {
			return .allButUpsideDown
		} else {
			return .all
		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	@IBAction func switch3DView(_ sender:UISwitch)
	{
		if (sender.isOn) {
			cmdView.isHidden = true
			let scnView = self.view.subviews[0] as! SCNView
			scnView.isHidden = false
		}
		else {
			cmdView.isHidden = false
			let scnView = self.view.subviews[0] as! SCNView
			scnView.isHidden = true
		}
	}
	
	@IBAction func buttonAction(_ sender:UIButton)
	{
		let idx = cmdView.indexPath(for: sender.superview!.superview as! UITableViewCell)
		let row = ((idx as NSIndexPath?)?.row)! as Int
		
		if (nebdev == nil) {
			return
		}
		
		if (row < NebCmdList.count) {
			switch (NebCmdList[row].SubSysId)
			{
				case NEB_CTRL_SUBSYS_EEPROM:
					switch (NebCmdList[row].CmdId)
					{
						case EEPROM_Read:
							nebdev!.eepromRead(0)
							break
						case EEPROM_Write:
								//UInt8_t eepdata[8]
								//nebdev.SendCmdEepromWrite(0, eepdata)
							break
						default:
							break
					}
					break
				default:
					break
			}
		}
	}
	
	@IBAction func switchAction(_ sender:UISegmentedControl)
	{
		//let tableView = sender.superview?.superview?.superview?.superview as! UITableView
		let idx = cmdView.indexPath(for: sender.superview!.superview as! UITableViewCell)
		let row = ((idx as NSIndexPath?)?.row)! as Int
		
		if (nebdev == nil) {
			return
		}
		
		if (row < NebCmdList.count) {
			switch (NebCmdList[row].SubSysId)
			{
				case NEB_CTRL_SUBSYS_DEBUG:
					switch (NebCmdList[row].CmdId)
					{
						case DEBUG_CMD_SET_INTERFACE:
							nebdev!.setInterface(sender.selectedSegmentIndex)
							break
						case DEBUG_CMD_DUMP_DATA:
							break;
						case DEBUG_CMD_SET_DATAPORT:
							nebdev!.setDataPort(row, Ctrl:UInt8(sender.selectedSegmentIndex))
							break;
						default:
							break
					}
					break
				
				case NEB_CTRL_SUBSYS_MOTION_ENG:
					switch (NebCmdList[row].CmdId)
					{
						case MotionState:
							nebdev!.streamMotionState(sender.selectedSegmentIndex == 1)
							break
						case SetFusionType:
							nebdev!.setFusionType(UInt8(sender.selectedSegmentIndex))
							break
						case IMU_Data:
							nebdev!.streamIMU(sender.selectedSegmentIndex == 1)
							break
						case Quaternion:
							nebdev!.streamEulerAngle(false)
							heading = false
							prevTimeStamp = 0
							nebdev!.streamQuaternion(sender.selectedSegmentIndex == 1)
							let i = getCmdIdx(0xf,  cmdId: 1)
							let cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
							if (cell != nil) {
								let sw = cell!.viewWithTag(1) as! UISegmentedControl
								sw.selectedSegmentIndex = 0
							}
							break
						case EulerAngle:
							nebdev!.streamQuaternion(false)
							nebdev!.streamEulerAngle(sender.selectedSegmentIndex == 1)
							break
						case ExtForce:
							nebdev!.streamExternalForce(sender.selectedSegmentIndex == 1)
							break
						case Pedometer:
							nebdev!.streamPedometer(sender.selectedSegmentIndex == 1)
							break;
						case TrajectoryRecStartStop:
							nebdev!.recordTrajectory(sender.selectedSegmentIndex == 1)
							break;
						case TrajectoryDistance:
							nebdev!.streamTrajectoryInfo(sender.selectedSegmentIndex == 1)
							break;
						case MAG_Data:
							nebdev!.streamMAG(sender.selectedSegmentIndex == 1)
							break;
						case LockHeadingRef:
							nebdev!.setLockHeadingReference(sender.selectedSegmentIndex == 1)
							let cell = cmdView.cellForRow( at: IndexPath(row: row, section: 0))
							if (cell != nil) {
								let sw = cell!.viewWithTag(1) as! UISegmentedControl
								sw.selectedSegmentIndex = 0
							}
							break
						default:
							break
					}
				case NEB_CTRL_SUBSYS_LED:
					let i = getCmdIdx(NEB_CTRL_SUBSYS_LED,  cmdId: LED_CMD_SET_VALUE)
					nebdev!.setLed(UInt8(row - i), Value: UInt8(sender.selectedSegmentIndex))
					break
				case NEB_CTRL_SUBSYS_STORAGE:
					switch (NebCmdList[row].CmdId)
					{
						
						case FlashEraseAll:
							if (sender.selectedSegmentIndex == 1) {
								flashEraseProgress = true;
							}
							nebdev!.eraseStorage(sender.selectedSegmentIndex == 1)
							break
						case FlashRecordStartStop:
							nebdev!.sessionRecord(sender.selectedSegmentIndex == 1)
							break
						case FlashPlaybackStartStop:
							nebdev!.sessionPlayback(sender.selectedSegmentIndex == 1, sessionId : 0xffff)
							if (sender.selectedSegmentIndex == 1) {
								PaketCnt = 0
							}
							break
						case FlashSessionRead:
							curDownloadSession = 0xFFFF
							curDownloadOffset = 0
							nebdev!.sessionRead(curDownloadSession, Len: 32, Offset: curDownloadOffset)
							break
						default:
							break
					}
					break
				case NEB_CTRL_SUBSYS_EEPROM:
					switch (NebCmdList[row].CmdId)
					{
						case EEPROM_Read:
							nebdev!.eepromRead(0)
							break
						case EEPROM_Write:
							//UInt8_t eepdata[8]
							//nebdev.SendCmdEepromWrite(0, eepdata)
							break
						default:
							break
					}
					break
				case 0xf:
					switch (NebCmdList[row].CmdId) {
						case Heading:
							nebdev!.streamQuaternion(false)
							nebdev!.streamEulerAngle(sender.selectedSegmentIndex == 1)
							heading = sender.selectedSegmentIndex == 1
							var i = getCmdIdx(NEB_CTRL_SUBSYS_MOTION_ENG,  cmdId: Quaternion)
							var cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
							if (cell != nil) {
								let control = cell!.viewWithTag(1) as! UISegmentedControl
								control.selectedSegmentIndex = 0
							}
							i = getCmdIdx(0xF,  cmdId: MotionDataStream)
							cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
							if (cell != nil) {
								let control = cell!.viewWithTag(1) as! UISegmentedControl
								control.selectedSegmentIndex = 0
							}
							break
						case MotionDataStream:
							if sender.selectedSegmentIndex == 0 {
								nebdev?.streamDisableAll()
								break
							}
							
							nebdev!.streamQuaternion(sender.selectedSegmentIndex == 1)
							var i = getCmdIdx(NEB_CTRL_SUBSYS_MOTION_ENG,  cmdId: Quaternion)
							var cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
							if (cell != nil) {
								let control = cell!.viewWithTag(1) as! UISegmentedControl
								control.selectedSegmentIndex = sender.selectedSegmentIndex
							}
							nebdev!.streamIMU(sender.selectedSegmentIndex == 1)
							i = getCmdIdx(NEB_CTRL_SUBSYS_MOTION_ENG,  cmdId: IMU_Data)
							cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
							if (cell != nil) {
								let control = cell!.viewWithTag(1) as! UISegmentedControl
								control.selectedSegmentIndex = sender.selectedSegmentIndex
							}
							nebdev!.streamMAG(sender.selectedSegmentIndex == 1)
							i = getCmdIdx(NEB_CTRL_SUBSYS_MOTION_ENG,  cmdId: MAG_Data)
							cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
							if (cell != nil) {
								let control = cell!.viewWithTag(1) as! UISegmentedControl
								control.selectedSegmentIndex = sender.selectedSegmentIndex
							}
							nebdev!.streamExternalForce(sender.selectedSegmentIndex == 1)
							i = getCmdIdx(NEB_CTRL_SUBSYS_MOTION_ENG,  cmdId: ExtForce)
							cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
							if (cell != nil) {
								let control = cell!.viewWithTag(1) as! UISegmentedControl
								control.selectedSegmentIndex = sender.selectedSegmentIndex
							}
							nebdev!.streamPedometer(sender.selectedSegmentIndex == 1)
							i = getCmdIdx(NEB_CTRL_SUBSYS_MOTION_ENG,  cmdId: Pedometer)
							cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
							if (cell != nil) {
								let control = cell!.viewWithTag(1) as! UISegmentedControl
								control.selectedSegmentIndex = sender.selectedSegmentIndex
							}
							nebdev!.streamRotationInfo(sender.selectedSegmentIndex == 1)
							i = getCmdIdx(NEB_CTRL_SUBSYS_MOTION_ENG,  cmdId: RotationInfo)
							cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
							if (cell != nil) {
								let control = cell!.viewWithTag(1) as! UISegmentedControl
								control.selectedSegmentIndex = sender.selectedSegmentIndex
							}
							i = getCmdIdx(0xF,  cmdId: Heading)
							cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
							if (cell != nil) {
								let control = cell!.viewWithTag(1) as! UISegmentedControl
								control.selectedSegmentIndex = 0
							}
							break
						default:
							break
					}
					break
				default:
					break
			}

		}
/*		else {
			switch (row - NebCmdList.count) {
			case 0:
				nebdev.streamQuaternion(false)
				nebdev.streamEulerAngle(true)
				heading = sender.selectedSegmentIndex == 1
				let i = getCmdIdx(NEB_CTRL_SUBSYS_MOTION_ENG,  cmdId: Quaternion)
				let cell = cmdView.cellForRowAtIndexPath( NSIndexPath(forRow: i, inSection: 0))
				if (cell != nil) {
					let sw = cell!.viewWithTag(1) as! UISegmentedControl
					sw.selectedSegmentIndex = 0
				}
				break
			default:
				break
			}
		}*/
	}
	
	//func renderer(renderer: SCNSceneRenderer,
	//	updateAtTime time: NSTimeInterval) {
//		let ship = renderer.scene!.rootNode.childNodeWithName("ship", recursively: true)!
//
//
//	}

//	func didReceiveFusionData(type : UInt8, data : FusionPacket) {
//		print("\(data)")
//	}
	// MARK : Neblina
	func didConnectNeblina() {
		// Switch to BLE interface
		prevTimeStamp = 0;
		//nebdev.SendCmdControlInterface(0)
		nebdev!.getMotionStatus()
		nebdev!.getDataPortState()
		nebdev!.getLed ()
		nebdev!.getFirmwareVersion()
	}
	
	func didReceiveRSSI(_ rssi : NSNumber) {
		
	}

	func didReceivePmgntData(_ type : Int32, data : UnsafePointer<UInt8>, dataLen: Int, errFlag : Bool) {
		let value = UInt16(data[0]) | (UInt16(data[1]) << 8)
		if (type == POWERMGMT_CMD_SET_CHARGE_CURRENT)
		{
			let i = getCmdIdx(NEB_CTRL_SUBSYS_POWERMGMT,  cmdId: POWERMGMT_CMD_SET_CHARGE_CURRENT)
			let cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
			if (cell != nil) {
				let control = cell!.viewWithTag(3) as! UITextField
				control.text = String(value)
			}
		}
	}

	func didReceiveFusionData(_ type : Int32, data : Fusion_DataPacket_t, errFlag : Bool) {

		//let errflag = Bool(type.rawValue & 0x80 == 0x80)

		//let id = FusionId(rawValue: type.rawValue & 0x7F)! as FusionId
		flashLabel.text = String(format: "Total packet %u @ %0.2f pps", nebdev!.getPacketCount(), nebdev!.getDataRate())
	
		switch (type) {
			
		case MotionState:
			break
		case IMU_Data:
			break
		case EulerAngle:
			//
			// Process Euler Angle
			//
			//let ship = scene.rootNode.childNodeWithName("ship", recursively: true)!
			let x = (Int16(data.data.0) & 0xff) | (Int16(data.data.1) << 8)
			let xrot = Float(x) / 10.0
			let y = (Int16(data.data.2) & 0xff) | (Int16(data.data.3) << 8)
			let yrot = Float(y) / 10.0
			let z = (Int16(data.data.4) & 0xff) | (Int16(data.data.5) << 8)
			let zrot = Float(z) / 10.0
			
			if (heading) {
				ship.eulerAngles = SCNVector3Make(GLKMathDegreesToRadians(90), 0, GLKMathDegreesToRadians(180) - GLKMathDegreesToRadians(xrot))
			}
			else {
				ship.eulerAngles = SCNVector3Make(GLKMathDegreesToRadians(180) - GLKMathDegreesToRadians(yrot), GLKMathDegreesToRadians(xrot), GLKMathDegreesToRadians(180) - GLKMathDegreesToRadians(zrot))
			}
			
			label.text = String("Euler - Yaw:\(xrot), Pitch:\(yrot), Roll:\(zrot)")
			
		
			break
		case Quaternion:
		
			//
			// Process Quaternion
			//
			//let ship = scene.rootNode.childNodeWithName("ship", recursively: true)!
			let x = (Int16(data.data.0) & 0xff) | (Int16(data.data.1) << 8)
			let xq = Float(x) / 32768.0
			let y = (Int16(data.data.2) & 0xff) | (Int16(data.data.3) << 8)
			let yq = Float(y) / 32768.0
			let z = (Int16(data.data.4) & 0xff) | (Int16(data.data.5) << 8)
			let zq = Float(z) / 32768.0
			let w = (Int16(data.data.6) & 0xff) | (Int16(data.data.7) << 8)
			let wq = Float(w) / 32768.0
			ship.orientation = SCNQuaternion(yq, xq, zq, wq)
			label.text = String("Quat - x:\(xq), y:\(yq), z:\(zq), w:\(wq)")
			if (prevTimeStamp == 0 || data.TimeStamp <= prevTimeStamp)
			{
				prevTimeStamp = data.TimeStamp;
			}
			else
			{
				let tdiff = data.TimeStamp - prevTimeStamp;
				if (tdiff > 49000)
				{
					dropCnt += 1
					dumpLabel.text = String("\(dropCnt) Drop : \(tdiff)")
				}
				prevTimeStamp = data.TimeStamp
			}
			
			break
		case ExtForce:
			//
			// Process External Force
			//
			//let ship = scene.rootNode.childNodeWithName("ship", recursively: true)!
			let x = (Int16(data.data.0) & 0xff) | (Int16(data.data.1) << 8)
			let xq = x / 1600
			let y = (Int16(data.data.2) & 0xff) | (Int16(data.data.3) << 8)
			let yq = y / 1600
			let z = (Int16(data.data.4) & 0xff) | (Int16(data.data.5) << 8)
			let zq = z / 1600

			cnt -= 1
			if (cnt <= 0) {
				cnt = max_count
				//if (xf != xq || yf != yq || zf != zq) {
				let pos = SCNVector3(CGFloat(xf/cnt), CGFloat(yf/cnt), CGFloat(zf/cnt))
				
				ship.position = pos
				
				xf = xq
				yf = yq
				zf = zq
				//}
			}
			else {
				//if (abs(xf) <= abs(xq)) {
					xf += xq
				//}
				//if (abs(yf) <= abs(yq)) {
					yf += yq
				//}
				//if (abs(xf) <= abs(xq)) {
					zf += zq
				//}
			}
			
			label.text = String("Extrn Force - x:\(xq), y:\(yq), z:\(zq)")
			//print("Extrn Force - x:\(xq), y:\(yq), z:\(zq)")
			break
		case MAG_Data:
			//
			// Mag data
			//
			//let ship = scene.rootNode.childNodeWithName("ship", recursively: true)!
			let x = (Int16(data.data.0) & 0xff) | (Int16(data.data.1) << 8)
			let xq = x
			let y = (Int16(data.data.2) & 0xff) | (Int16(data.data.3) << 8)
			let yq = y
			let z = (Int16(data.data.4) & 0xff) | (Int16(data.data.5) << 8)
			let zq = z
			label.text = String("Mag - x:\(xq), y:\(yq), z:\(zq)")
			
			//ship.rotation = SCNVector4(Float(xq), Float(yq), 0, GLKMathDegreesToRadians(90))
			break
			
		default:
			break
		}
		
		
	}
	
	func didReceiveDebugData(_ type : Int32, data : UnsafePointer<UInt8>, dataLen: Int, errFlag : Bool)
	{
		switch (type) {
			case DEBUG_CMD_MOTENGINE_RECORDER_STATUS:
				switch (data[8]) {
					case 1:	// Playback
						var i = getCmdIdx(NEB_CTRL_SUBSYS_STORAGE,  cmdId: FlashRecordStartStop)
						var cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
						if (cell != nil) {
							let sw = cell!.viewWithTag(1) as! UISegmentedControl
							sw.selectedSegmentIndex = 0
						}
						i = getCmdIdx(NEB_CTRL_SUBSYS_STORAGE,  cmdId: FlashPlaybackStartStop)
						cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
						if (cell != nil) {
							let sw = cell!.viewWithTag(1) as! UISegmentedControl
							sw.selectedSegmentIndex = 1
						}
						break
					case 2:	// Recording
						var i = getCmdIdx(NEB_CTRL_SUBSYS_STORAGE,  cmdId: FlashPlaybackStartStop)
						var cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
						if (cell != nil) {
							let sw = cell!.viewWithTag(1) as! UISegmentedControl
							sw.selectedSegmentIndex = 0
						}
						i = getCmdIdx(NEB_CTRL_SUBSYS_STORAGE,  cmdId: FlashRecordStartStop)
						cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
						if (cell != nil) {
							let sw = cell!.viewWithTag(1) as! UISegmentedControl
							sw.selectedSegmentIndex = 1
						}
						break
					default:
						var i = getCmdIdx(NEB_CTRL_SUBSYS_STORAGE,  cmdId: FlashPlaybackStartStop)
						var cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
						if (cell != nil) {
							let sw = cell!.viewWithTag(1) as! UISegmentedControl
							sw.selectedSegmentIndex = 0
						}
						i = getCmdIdx(NEB_CTRL_SUBSYS_STORAGE,  cmdId: FlashRecordStartStop)
						cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
						if (cell != nil) {
							let sw = cell!.viewWithTag(1) as! UISegmentedControl
							sw.selectedSegmentIndex = 0
						}
						break
				}
				var i = getCmdIdx(NEB_CTRL_SUBSYS_MOTION_ENG,  cmdId: Quaternion)
				var cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
				if (cell != nil) {
					let sw = cell!.viewWithTag(1) as! UISegmentedControl
					sw.selectedSegmentIndex = Int(data[4] & 8) >> 3
				}
				i = getCmdIdx(NEB_CTRL_SUBSYS_MOTION_ENG,  cmdId: MAG_Data)
				cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
				if (cell != nil) {
					let sw = cell!.viewWithTag(1) as! UISegmentedControl
					sw.selectedSegmentIndex = Int(data[4] & 0x80) >> 7
				}

				//				i = nebdev.getCmdIdx(NEB_CTRL_SUBSYS_MOTION_ENG,  cmdId: EulerAngle)
/*				cell = cmdView.cellForRowAtIndexPath( NSIndexPath(forRow: NebCmdList.count, inSection: 0))
				sw = cell!.viewWithTag(2) as! UISegmentedControl
				sw.selectedSegmentIndex = Int(data[4] & 0x4) >> 2*/
				//print("\(d)")
				
				break
			case DEBUG_CMD_GET_FW_VERSION:
				versionLabel.text = String(format: "API:%d, FEN:%d.%d.%d, BLE:%d.%d.%d", data[0], data[1], data[2], data[3], data[4], data[5], data[6])
				break
			case DEBUG_CMD_DUMP_DATA:
				dumpLabel.text = String(format: "%02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x",
				                        data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7], data[8], data[9],
										data[10], data[11], data[12], data[13], data[14], data[15])
				break
			case DEBUG_CMD_GET_DATAPORT:
				let i = getCmdIdx(NEB_CTRL_SUBSYS_DEBUG,  cmdId: DEBUG_CMD_SET_DATAPORT)
				var cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
				if (cell != nil) {
					let sw = cell!.viewWithTag(1) as! UISegmentedControl
					sw.selectedSegmentIndex = Int(data[0])
				}
				cell = cmdView.cellForRow( at: IndexPath(row: i + 1, section: 0))
				if (cell != nil) {
					let sw = cell!.viewWithTag(1) as! UISegmentedControl
					sw.selectedSegmentIndex = Int(data[1])
				}
				break
			default:
				break
		}
	}
	
	func didReceiveStorageData(_ type : Int32, data : UnsafePointer<UInt8>, dataLen: Int, errFlag : Bool) {
		switch (type) {
			case FlashEraseAll:
				flashLabel.text = "Flash erased"
				break
			case FlashRecordStartStop:
				let session = Int16(data[5]) | (Int16(data[6]) << 8)
				if (data[4] != 0) {
					flashLabel.text = String(format: "Recording session %d", session)
				}
				else {
					flashLabel.text = String(format: "Recorded session %d", session)
				}
				break
			case FlashPlaybackStartStop:
				let session = Int16(data[5]) | (Int16(data[6]) << 8)
				if (data[4] != 0) {
					flashLabel.text = String(format: "Playing session %d", session)
				}
				else {
					flashLabel.text = String(format: "End session %d, %u", session, nebdev!.getPacketCount())
					
					let i = getCmdIdx(NEB_CTRL_SUBSYS_STORAGE,  cmdId: FlashPlaybackStartStop)
					let cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
					if (cell != nil) {
						let sw = cell!.viewWithTag(1) as! UISegmentedControl
						sw.selectedSegmentIndex = 0
					}
				}
				break
			default:
				break
		}
	}
	
	func didReceiveEepromData(_ type : Int32, data : UnsafePointer<UInt8>, dataLen: Int, errFlag : Bool) {
		switch (type) {
			case EEPROM_Read:
				let pageno = UInt16(data[0]) | (UInt16(data[1]) << 8)
				dumpLabel.text = String(format: "EEP page [%d] : %02x %02x %02x %02x %02x %02x %02x %02x",
					pageno, data[2], data[3], data[4], data[5], data[6], data[7], data[8], data[9])
				break
			case EEPROM_Write:
				break;
			default:
				break
		}
	}
	
	func didReceiveLedData(_ type : Int32, data : UnsafePointer<UInt8>, dataLen: Int, errFlag : Bool) {
		switch (type) {
			case LED_CMD_GET_VALUE:
				let i = getCmdIdx(NEB_CTRL_SUBSYS_LED,  cmdId: LED_CMD_SET_VALUE)
				var cell = cmdView.cellForRow( at: IndexPath(row: i, section: 0))
				if (cell != nil) {
					let tf = cell!.viewWithTag(3) as! UITextField
					tf.text = String(data[0])
				}
				cell = cmdView.cellForRow( at: IndexPath(row: i + 1, section: 0))
				if (cell != nil) {
					let tf = cell!.viewWithTag(3) as! UITextField
					tf.text = String(data[1])
				}
				cell = cmdView.cellForRow( at: IndexPath(row: i + 2, section: 0))
				if (cell != nil) {
					let sw = cell!.viewWithTag(1) as! UISegmentedControl
					if (data[2] != 0) {
						sw.selectedSegmentIndex = 1
					}
					else {
						sw.selectedSegmentIndex = 0
					}
				}
				break
			default:
				break
		}
	}

	// MARK : UITableView
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		
		return /*FusionCmdList.count + */NebCmdList.count //+ CtrlName.count
		//return 1//detailItem
	}
	
	func tableView(_ tableView: UITableView, cellForRowAtIndexPath indexPath: IndexPath?) -> UITableViewCell?
	{
		let cellView = tableView.dequeueReusableCell(withIdentifier: "CellCommand", for: indexPath!)
		let labelView = cellView.viewWithTag(255) as! UILabel
//		let switchCtrl = cellView.viewWithTag(2) as! UIControl//UISegmentedControl
//		var buttonCtrl = cellView.viewWithTag(3) as! UIButton
//		buttonCtrl.hidden = true
		
		//switchCtrl.addTarget(self, action: "switchAction:", forControlEvents: UIControlEvents.ValueChanged)
/*		if (indexPath!.row < FusionCmdList.count) {
			labelView.text = FusionCmdList[indexPath!.row].Name //NebApiName[indexPath!.row] as String//"Row \(row)"//"self.objects.objectAtIndex(row) as! String
		} else */
		if ((indexPath! as NSIndexPath).row < /*FusionCmdList.count + */NebCmdList.count) {
			
			labelView.text = NebCmdList[(indexPath! as NSIndexPath).row].Name// - FusionCmdList.count].Name
			switch (NebCmdList[(indexPath! as NSIndexPath).row].Actuator)
			{
				case 1:
					let control = cellView.viewWithTag(NebCmdList[(indexPath! as NSIndexPath).row].Actuator) as! UISegmentedControl
					control.isHidden = false
					let b = cellView.viewWithTag(2) as! UIButton
					b.isHidden = true
					let t = cellView.viewWithTag(3) as! UITextField
					t.isHidden = true
					break
				case 2:
					let control = cellView.viewWithTag(NebCmdList[(indexPath! as NSIndexPath).row].Actuator) as! UIButton
					control.isHidden = false
					if !NebCmdList[(indexPath! as NSIndexPath).row].Text.isEmpty
					{
						control.setTitle(NebCmdList[(indexPath! as NSIndexPath).row].Text, for: UIControlState())
					}
					let s = cellView.viewWithTag(1) as! UISegmentedControl
					s.isHidden = true
					let t = cellView.viewWithTag(3) as! UITextField
					t.isHidden = true
					break
				case 3:
					let control = cellView.viewWithTag(NebCmdList[(indexPath! as NSIndexPath).row].Actuator) as! UITextField
					control.isHidden = false
					if !NebCmdList[(indexPath! as NSIndexPath).row].Text.isEmpty
					{
						control.text = NebCmdList[(indexPath! as NSIndexPath).row].Text
					}
					let s = cellView.viewWithTag(1) as! UISegmentedControl
					s.isHidden = true
					let b = cellView.viewWithTag(2) as! UIButton
					b.isHidden = true
					break
				default:
					//switchCtrl.enabled = false
//					switchCtrl.hidden = true
//					buttonCtrl.hidden = true
					break
			}
		}
//		else {
//			labelView.text = CtrlName[indexPath!.row /*- FusionCmdList.count*/ - NebCmdList.count] //NebApiName[indexPath!.row] as String//"Row \(row)"//"self.objects.objectAtIndex(row) as! String
//		}
		
		
		//cellView.textLabel!.text = NebApiName[indexPath!.row] as String//"Row \(row)"//"self.objects.objectAtIndex(row) as! String
			
		return cellView;
	}

	func tableView(_ tableView: UITableView, canEditRowAtIndexPath indexPath: IndexPath?) -> Bool
	{
		return false
	}
	func scrollViewDidScroll(_ scrollView: UIScrollView)
	{
		if (nebdev == nil) {
			return
		}
		
		nebdev!.getMotionStatus()
		nebdev!.getDataPortState()
		nebdev!.getLed()
	}
}

