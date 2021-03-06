//
//  File.swift
//  NeblinaCtrlPanel
//
//  Created by Hoan Hoang on 2015-10-07.
//  Copyright © 2015 Hoan Hoang. All rights reserved.
//

import Foundation
import CoreBluetooth

// BLE custom UUID
let NEB_SERVICE_UUID = CBUUID (string:"0df9f021-1532-11e5-8960-0002a5d5c51b")
let NEB_DATACHAR_UUID = CBUUID (string:"0df9f022-1532-11e5-8960-0002a5d5c51b")
let NEB_CTRLCHAR_UUID = CBUUID (string:"0df9f023-1532-11e5-8960-0002a5d5c51b")

class Neblina : NSObject, CBPeripheralDelegate {
	var id = UInt64(0)
	var device : CBPeripheral!
	var dataChar : CBCharacteristic! = nil
	var ctrlChar : CBCharacteristic! = nil
	var NebPkt = NEB_PKT()
	var fp = Fusion_DataPacket_t()
	var delegate : NeblinaDelegate!
	//var devid : UInt64 = 0
	var packetCnt : UInt32 = 0		// Data packet count
	var startTime : UInt64 = 0
	var currTime : UInt64 = 0
	var dataRate : Float = 0.0
	var timeBaseInfo = mach_timebase_info(numer: 0, denom:0)
	
	init(devid : UInt64, peripheral : CBPeripheral?) {
		super.init()
		if (peripheral != nil) {
			id = devid
			device = peripheral
			device.delegate = self
		}
		else {
			id = 0
			device = nil
		}
	}
	func setPeripheral(_ devid : UInt64, peripheral : CBPeripheral) {
		device = peripheral
		id = devid
		device.delegate = self
		device.discoverServices([NEB_SERVICE_UUID])
		_ = mach_timebase_info(numer: 0, denom:0)
		mach_timebase_info(&timeBaseInfo)
	}
	
	func connected(_ peripheral : CBPeripheral) {
		device.discoverServices([NEB_SERVICE_UUID])
	}

	//
	// CBPeripheral stuffs
	//
	
	func peripheralDidUpdateRSSI(_ peripheral: CBPeripheral, error: Error?) {
		if (device.rssi != nil) {
			delegate.didReceiveRSSI(device.rssi!)
		}
	}
	
	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?)
	{
		for service in peripheral.services ?? []
		{
			if (service.uuid .isEqual(NEB_SERVICE_UUID))
			{
				peripheral.discoverCharacteristics(nil, for: service)
			}
		}
	}
	
	func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?)
	{
		for characteristic in service.characteristics ?? []
		{
			//print("car \(characteristic.UUID)");
			if (characteristic.uuid .isEqual(NEB_DATACHAR_UUID))
			{
				dataChar = characteristic;
				if ((dataChar.properties.rawValue & CBCharacteristicProperties.notify.rawValue) != 0)
				{
					print("Data \(characteristic.uuid)");
					peripheral.setNotifyValue(true, for: dataChar);
					packetCnt = 0	// reset packet count
					startTime = 0	// reset timer
				}
			}
			if (characteristic.uuid .isEqual(NEB_CTRLCHAR_UUID))
			{
				print("Ctrl \(characteristic.uuid)");
				ctrlChar = characteristic;
			}
		}
	}
	
	func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?)
	{
		if (delegate != nil) {
			delegate.didConnectNeblina()
		}
	}
	
	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
	{
		var hdr = NEB_PKTHDR()
		if (characteristic.uuid .isEqual(NEB_DATACHAR_UUID) && characteristic.value != nil)
		{
			var ch = [UInt8](repeating: 0, count: 20)
			characteristic.value?.copyBytes(to: &ch, count: MemoryLayout<NEB_PKTHDR>.size)
			hdr = (characteristic.value?.withUnsafeBytes{ (ptr: UnsafePointer<NEB_PKTHDR>) -> NEB_PKTHDR in return ptr.pointee })!

			let id = Int32(hdr.Cmd)
			var errflag = Bool(false)
			

			if (Int32(hdr.PkType) == NEB_CTRL_PKTYPE_ACK) {
				//print("ACK : \(characteristic.value)")
				return
			}
			
	/*		if ((hdr.SubSys  & 0x80) == 0x80)
			{
				errflag = true;
				hdr.SubSys &= 0x7F;
			}*/
			if (Int32(hdr.PkType) == NEB_CTRL_PKTYPE_ERR)
			{
				errflag = true;
			}
			
			packetCnt += 1
			
			if (startTime == 0) {
				// first time use
				startTime = mach_absolute_time()
			}
			else {
				currTime = mach_absolute_time()
				let elapse = currTime - startTime
				if (elapse > 0) {
					dataRate = Float(UInt64(packetCnt) * 1000000000 * UInt64(timeBaseInfo.denom)) / Float((currTime - startTime) * UInt64(timeBaseInfo.numer))
				}
			}
			
			switch (Int32(hdr.SubSys))
			{
				case NEB_CTRL_SUBSYS_MOTION_ENG:	// Motion Engine
					let dd = (characteristic.value?.subdata(in: Range(4..<20)))!
					fp = (dd.withUnsafeBytes{ (ptr: UnsafePointer<Fusion_DataPacket_t>) -> Fusion_DataPacket_t in return ptr.pointee })
					delegate.didReceiveFusionData(id, data: fp, errFlag: errflag)
					break
				case NEB_CTRL_SUBSYS_DEBUG:
					var dd = [UInt8](repeating: 0, count: 16)
					//(characteristic.value as Data).copyBytes(to: &dd, from:4)
					if (hdr.Len > 0) {
						characteristic.value?.copyBytes (to: &dd, from: Range(MemoryLayout<NEB_PKTHDR>.size..<Int(hdr.Len) + MemoryLayout<NEB_PKTHDR>.size))
					}

					delegate.didReceiveDebugData(id, data: dd, dataLen: Int(hdr.Len), errFlag: errflag)
					break
				case NEB_CTRL_SUBSYS_POWERMGMT:
					var dd = [UInt8](repeating: 0, count: 16)
					if (hdr.Len > 0) {
						characteristic.value?.copyBytes (to: &dd, from: Range(MemoryLayout<NEB_PKTHDR>.size..<Int(hdr.Len) + MemoryLayout<NEB_PKTHDR>.size))
					}
					delegate.didReceivePmgntData(id, data: dd, dataLen: Int(hdr.Len), errFlag: errflag)
					break
				case NEB_CTRL_SUBSYS_STORAGE:
					var dd = [UInt8](repeating: 0, count: 16)
					if (hdr.Len > 0) {
						characteristic.value?.copyBytes (to: &dd, from: Range(MemoryLayout<NEB_PKTHDR>.size..<Int(hdr.Len) + MemoryLayout<NEB_PKTHDR>.size))
					}
					delegate.didReceiveStorageData(id, data: dd, dataLen: Int(hdr.Len), errFlag: errflag)
					break
				case NEB_CTRL_SUBSYS_EEPROM:
					var dd = [UInt8](repeating: 0, count: 16)
					if (hdr.Len > 0) {
						characteristic.value?.copyBytes (to: &dd, from: Range(MemoryLayout<NEB_PKTHDR>.size..<Int(hdr.Len) + MemoryLayout<NEB_PKTHDR>.size))
					}
					delegate.didReceiveEepromData(id, data: dd, dataLen: Int(hdr.Len), errFlag: errflag)
					break
				case NEB_CTRL_SUBSYS_LED:
					var dd = [UInt8](repeating: 0, count: 16)
					if (hdr.Len > 0) {
						characteristic.value?.copyBytes (to: &dd, from: Range(MemoryLayout<NEB_PKTHDR>.size..<Int(hdr.Len) + MemoryLayout<NEB_PKTHDR>.size))
					}
					delegate.didReceiveLedData(id, data: dd, dataLen: Int(hdr.Len), errFlag: errflag)
					break

				default:
					break
			}
			
		}
	}
	func isDeviceReady()-> Bool {
		if (device == nil || ctrlChar == nil) {
			return false
		}
		
		if (device.state != CBPeripheralState.connected) {
			return false
		}
		
		return true
	}
	
	func getPacketCount()-> UInt32 {
		return packetCnt
	}
	
	func getDataRate()->Float {
		return dataRate
	}
	
	// MARK : **** API
	func crc8(_ data : [UInt8], Len : Int) -> UInt8
	{
		var i = Int(0)
		var e = UInt8(0)
		var f = UInt8(0)
		var crc = UInt8(0)
		
		//for (i = 0; i < Len; i += 1)
		while i < Len {
			e = crc ^ data[i];
			f = e ^ (e >> 4) ^ (e >> 7);
			crc = (f << 1) ^ (f << 4);
			i += 1
		}
	
		return crc;
	}

	// Debug
	func getDataPortState() {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_DEBUG) // 0x40
		pkbuf[1] = 0	// Data len
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(DEBUG_CMD_GET_DATAPORT)	// Cmd
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)
		
		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func getFirmwareVersion() {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_DEBUG)
		pkbuf[1] = 0
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(DEBUG_CMD_GET_FW_VERSION)	// Cmd
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func getMotionStatus() {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_DEBUG)
		pkbuf[1] = 16
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(DEBUG_CMD_MOTENGINE_RECORDER_STATUS)	// Cmd
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func getRecorderStatus() {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_DEBUG)
		pkbuf[1] = 16
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(DEBUG_CMD_MOTENGINE_RECORDER_STATUS)	// Cmd
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func setDataPort(_ PortIdx : Int, Ctrl : UInt8) {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_DEBUG) // 0x40
		pkbuf[1] = 2
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(DEBUG_CMD_SET_DATAPORT)	// Cmd
		
		// Port = 0 : BLE
		// Port = 1 : UART
		pkbuf[4] = UInt8(PortIdx)
		pkbuf[5] = Ctrl		// 1 - Open, 0 - Close
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func setInterface(_ Interf : Int) {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_DEBUG) // 0x40
		pkbuf[1] = 16
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(DEBUG_CMD_SET_INTERFACE)	// Cmd
		
		// Interf = 0 : BLE
		// Interf = 1 : UART
		pkbuf[4] = UInt8(Interf)
		pkbuf[8] = 0
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	// *** EEPROM
	func eepromRead(_ pageNo : UInt16) {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_EEPROM)
		pkbuf[1] = 16
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(EEPROM_Read) // Cmd
		
		pkbuf[4] = UInt8(pageNo & 0xff)
		pkbuf[5] = UInt8((pageNo >> 8) & 0xff)
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func eepromWrite(_ pageNo : UInt16, data : UnsafePointer<UInt8>) {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_EEPROM)
		pkbuf[1] = 16
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(EEPROM_Write) // Cmd
		
		pkbuf[4] = UInt8(pageNo & 0xff)
		pkbuf[5] = UInt8((pageNo >> 8) & 0xff)
		
		//for (i, 0 ..< 8, i++) {
		//	pkbuf[i + 6] = data[i]
		//}
		for i in 0..<8 {
			pkbuf[i + 6] = data[i]
		}
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)
		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	// *** LED subsystem commands
	func getLed() {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_LED)
		pkbuf[1] = 0	// Data length
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(LED_CMD_GET_VALUE)	// Cmd
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func setLed(_ LedNo : UInt8, Value:UInt8) {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_LED)
		pkbuf[1] = 16 //UInt8(sizeof(Fusion_DataPacket_t))
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(LED_CMD_SET_VALUE)	// Cmd
		
		// Nb of LED to set
		pkbuf[4] = 1
		pkbuf[5] = LedNo
		pkbuf[6] = Value
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	// *** Power management sybsystem commands
	func getTemperature() {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_POWERMGMT)
		pkbuf[1] = 0	// Data length
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(POWERMGMT_CMD_GET_TEMPERATURE)	// Cmd
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func setBatteryChargeCurrent(_ Current: UInt16) {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_POWERMGMT)
		pkbuf[1] = 2	// Data length
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(POWERMGMT_CMD_SET_CHARGE_CURRENT)	// Cmd
		
		// Data
		pkbuf[4] = UInt8(Current & 0xFF)
		pkbuf[5] = UInt8((Current >> 8) & 0xFF)
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}

	// *** Motion Settings
	func setAccelerometerRange(_ Mode: UInt8) {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_MOTION_ENG) //0x41
		pkbuf[1] = UInt8(MemoryLayout<Fusion_DataPacket_t>.size)
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(SetAccRange)	// Cmd
		pkbuf[8] = Mode
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func setFusionType(_ Mode:UInt8) {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_MOTION_ENG) //0x41
		pkbuf[1] = UInt8(MemoryLayout<Fusion_DataPacket_t>.size)
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(SetFusionType)	// Cmd
		
		// Data
		pkbuf[8] = Mode
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func setLockHeadingReference(_ Enable:Bool) {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_MOTION_ENG) //0x41
		pkbuf[1] = UInt8(MemoryLayout<Fusion_DataPacket_t>.size)
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(LockHeadingRef)	// Cmd
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	// *** Motion Streaming Send
	func streamDisableAll()
	{
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_MOTION_ENG)
		pkbuf[1] = UInt8(MemoryLayout<Fusion_DataPacket_t>.size)
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(DisableAllStreaming)	// Cmd
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func streamEulerAngle(_ Enable:Bool)
	{
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_MOTION_ENG) //0x41
		pkbuf[1] = UInt8(MemoryLayout<Fusion_DataPacket_t>.size)
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(EulerAngle)// Cmd
		
		if (Enable == true)
		{
			pkbuf[8] = 1
		}
		else
		{
			pkbuf[8] = 0
		}
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func streamExternalForce(_ Enable:Bool)
	{
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_MOTION_ENG) //0x41
		pkbuf[1] = UInt8(MemoryLayout<Fusion_DataPacket_t>.size)
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(ExtForce)	// Cmd
		
		if (Enable == true)
		{
			pkbuf[8] = 1
		}
		else
		{
			pkbuf[8] = 0
		}
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func streamIMU(_ Enable:Bool)
	{
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_MOTION_ENG) //0x41
		pkbuf[1] = UInt8(MemoryLayout<Fusion_DataPacket_t>.size)
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(IMU_Data)	// Cmd
		
		if Enable == true
		{
			pkbuf[8] = 1
		}
		else
		{
			pkbuf[8] = 0
		}
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func streamMAG(_ Enable:Bool)
	{
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_MOTION_ENG) //0x41
		pkbuf[1] = UInt8(MemoryLayout<Fusion_DataPacket_t>.size)
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(MAG_Data)	// Cmd
		
		if Enable == true
		{
			pkbuf[8] = 1
		}
		else
		{
			pkbuf[8] = 0
		}
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func streamMotionState(_ Enable:Bool)
	{
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_MOTION_ENG) //0x41
		pkbuf[1] = UInt8(MemoryLayout<Fusion_DataPacket_t>.size)
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(MotionState)	// Cmd
		
		if Enable == true
		{
			pkbuf[8] = 1
		}
		else
		{
			pkbuf[8] = 0
		}
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}

	func streamPedometer(_ Enable:Bool)
	{
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_MOTION_ENG) //0x41
		pkbuf[1] = UInt8(MemoryLayout<Fusion_DataPacket_t>.size)
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(Pedometer)// Cmd
		
		if Enable == true
		{
			pkbuf[8] = 1
		}
		else
		{
			pkbuf[8] = 0
		}
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func streamQuaternion(_ Enable:Bool)
	{
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_MOTION_ENG) //0x41
		pkbuf[1] = UInt8(MemoryLayout<Fusion_DataPacket_t>.size)
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(Quaternion)	// Cmd
		
		if (Enable == true)
		{
			pkbuf[8] = 1
		}
		else
		{
			pkbuf[8] = 0
		}
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func streamRotationInfo(_ Enable:Bool) {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_MOTION_ENG) //0x41
		pkbuf[1] = UInt8(MemoryLayout<Fusion_DataPacket_t>.size)
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(RotationInfo)	// Cmd
		
		if Enable == true
		{
			pkbuf[8] = 1
		}
		else
		{
			pkbuf[8] = 0
		}
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func streamSittingStanding(_ Enable:Bool) {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_MOTION_ENG) //0x41
		pkbuf[1] = UInt8(MemoryLayout<Fusion_DataPacket_t>.size)
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(SittingStanding)	// Cmd
		
		if Enable == true
		{
			pkbuf[8] = 1
		}
		else
		{
			pkbuf[8] = 0
		}
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func streamTrajectoryInfo(_ Enable:Bool)
	{
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_MOTION_ENG) //0x41
		pkbuf[1] = UInt8(MemoryLayout<Fusion_DataPacket_t>.size)
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(TrajectoryInfo)	// Cmd
		
		if Enable == true
		{
			pkbuf[8] = 1
		}
		else
		{
			pkbuf[8] = 0
		}
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	// *** Motion utilities
	func resetTimeStamp() {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_MOTION_ENG)
		pkbuf[1] = UInt8(MemoryLayout<Fusion_DataPacket_t>.size)
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(ResetTimeStamp)	// Cmd
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func recordTrajectory(_ Enable:Bool)
	{
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_MOTION_ENG) //0x41
		pkbuf[1] = UInt8(MemoryLayout<Fusion_DataPacket_t>.size)
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(TrajectoryRecStartStop)	// Cmd
		
		if Enable == true
		{
			pkbuf[8] = 1
		}
		else
		{
			pkbuf[8] = 0
		}
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	// *** Storage subsystem commands
	func getSessionCount() {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_STORAGE)
		pkbuf[1] = 16
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(FlashGetNbSessions) // Cmd
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func getSessionInfo(_ sessionId : UInt16) {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_STORAGE)
		pkbuf[1] = 16
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(FlashGetSessionInfo) // Cmd
		
		pkbuf[8] = UInt8(sessionId & 0xff)
		pkbuf[9] = UInt8((sessionId >> 8) & 0xff)
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func eraseStorage(_ Enable:Bool) {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_STORAGE) //0x41
		pkbuf[1] = 16
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(FlashEraseAll) // Cmd
		
		if Enable == true
		{
			pkbuf[8] = 1
		}
		else
		{
			pkbuf[8] = 0
		}
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
		
	}
	
	func sessionPlayback(_ Enable:Bool, sessionId : UInt16) {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_STORAGE)
		pkbuf[1] = 16
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(FlashPlaybackStartStop) // Cmd
		
		if Enable == true
		{
			pkbuf[8] = 1
		}
		else
		{
			pkbuf[8] = 0
		}
		
		pkbuf[9] = UInt8(sessionId & 0xff)
		pkbuf[10] = UInt8((sessionId >> 8) & 0xff)
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func sessionRecord(_ Enable:Bool) {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_STORAGE) //0x41
		pkbuf[1] = 16
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(FlashRecordStartStop)	// Cmd
		
		if Enable == true
		{
			pkbuf[8] = 1
		}
		else
		{
			pkbuf[8] = 0
		}
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
	func sessionRead(_ SessionId:UInt16, Len:UInt16, Offset:UInt32) {
		if (isDeviceReady() == false) {
			return
		}
		
		var pkbuf = [UInt8](repeating: 0, count: 20)
		
		pkbuf[0] = UInt8((NEB_CTRL_PKTYPE_CMD << 5) | NEB_CTRL_SUBSYS_STORAGE) //0x41
		pkbuf[1] = 16
		pkbuf[2] = 0xFF
		pkbuf[3] = UInt8(FlashSessionRead)	// Cmd

		// Command parameter
		pkbuf[4] = UInt8(SessionId & 0xFF)
		pkbuf[5] = UInt8((SessionId >> 8) & 0xFF)
		pkbuf[6] = UInt8(Len & 0xFF)
		pkbuf[7] = UInt8((Len >> 8) & 0xFF)
		pkbuf[8] = UInt8(Offset & 0xFF)
		pkbuf[9] = UInt8((Offset >> 8) & 0xFF)
		pkbuf[10] = UInt8((Offset >> 16) & 0xFF)
		pkbuf[11] = UInt8((Offset >> 24) & 0xFF)
		
		pkbuf[2] = crc8(pkbuf, Len: Int(pkbuf[1]) + 4)

		device.writeValue(Data(bytes: pkbuf, count: 4 + Int(pkbuf[1])), for: ctrlChar, type: CBCharacteristicWriteType.withoutResponse)
	}
	
}

protocol NeblinaDelegate {
	
	func didConnectNeblina()
	func didReceiveRSSI(_ rssi : NSNumber)
	func didReceiveFusionData(_ type : Int32, data : Fusion_DataPacket_t, errFlag : Bool)
	func didReceiveDebugData(_ type : Int32, data : UnsafePointer<UInt8>, dataLen : Int, errFlag : Bool)
	func didReceivePmgntData(_ type : Int32, data : UnsafePointer<UInt8>, dataLen : Int, errFlag : Bool)
	func didReceiveStorageData(_ type : Int32, data : UnsafePointer<UInt8>, dataLen : Int, errFlag : Bool)
	func didReceiveEepromData(_ type : Int32, data : UnsafePointer<UInt8>, dataLen : Int, errFlag : Bool)
	func didReceiveLedData(_ type : Int32, data : UnsafePointer<UInt8>, dataLen : Int, errFlag : Bool)
}
