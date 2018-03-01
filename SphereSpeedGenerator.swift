//
//  SphereSpeedGenerator.swift
//  placeCalculator
//
//  Created by IUILAB on 2017/1/20.
//  Copyright © 2017年 IUILAB. All rights reserved.
//
//計算球狀座標系的移動指令
import Foundation
import CoreLocation
class SphereSpeedGenerator{
    fileprivate var _updateRate: Float = 0.1 //更新週期
    fileprivate var _radius: Float = 3.0//圓半徑
    fileprivate var _velocity: Float = 1.0//速度（同柱狀座標）
    fileprivate var _sphereCenter: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid
    fileprivate var _accumVerticalAngle: Double = 0.0 //上下移動累積已移動的角度
    fileprivate var horizontalTrack: CylinderSpeedBooster? //水平移動直接使用柱狀座標系的class來進行計算
    fileprivate var prevTime: Date = Date() //前一次指令的時間
    fileprivate var velocityAdjust: Date = Date() //
    fileprivate var horizontalChecker: CircularLocationTransform = CircularLocationTransform()//水平位置確認
    fileprivate var isStartMoving: Bool = false //是否開始移動
    fileprivate var isSlowStart: Bool = false //是否採用慢速啟動機制（效果不佳，可刪除）
    fileprivate var speedModifier: Float = 1 //慢速啟動速度變化變數（效果不佳，可刪除）
    var radius: Float {
        get{
            return self._radius
        }
        set{
            if newValue > 2 {
                if newValue > 15 {
                    self._radius = 15
                }
                else {
                    self._radius = newValue
                }
                horizontalTrack?.radius = self._radius * Float(cos(accumVerticalAngle))
                horizontalChecker.radius = Double(self._radius) * (cos(accumVerticalAngle))
            }else{
                self._radius = 2.0
//                self._radius = newValue
                horizontalTrack?.radius = self._radius * Float(cos(accumVerticalAngle))
                horizontalChecker.radius = Double(self._radius) * (cos(accumVerticalAngle))
            }
        }
    }
    var velocity:Float {
        get{
            if isSlowStart {
                return self._velocity * speedModifier
            }else{
                return self._velocity
            }
        }
        set{
            if newValue > 0 {
                self._velocity = newValue
                horizontalTrack?.velocity = self._velocity
            }
        }
    }
    var sphereCenter: CLLocationCoordinate2D{
        get{
            return self._sphereCenter
        }
        set{
            if newValue.latitude < 90 && newValue.longitude < 180 && newValue.latitude > -90 && newValue.longitude > -180{
                self._sphereCenter = newValue
                horizontalTrack?.cylinderCenter = self._sphereCenter
                horizontalChecker.center = self._sphereCenter
            }
        }
    }

    var updateRate: Float{
        get{
            return _updateRate
        }
        set{
            if newValue > 0.04 && newValue < 0.2 {
                self._updateRate = newValue
                horizontalTrack?.updateRate = self._updateRate
            }
        }
    }

    var singleVerticalRotate: Double { //印象中這是大改版前的變數可刪除
        get{
            return  asin(Double(_updateRate * _velocity / 2 / _radius))
        }
    }
    var singleElevationRotate: Double{ //垂直移動每次移動的圓心角
        get{
            return Double(self.velocity * self.updateRate / self.radius)
        }
    }
    var singleVelocityTrans: Double{ //移動後的圓心角
        get{
            return self.accumVerticalAngle + Double(self.velocity * self.updateRate / self.radius / 2)
        }
    }
    var angleOfElevation:Float{ //飛機由圓心看出去的垂直仰角位置
        get{
            return radTrans(radVal: accumVerticalAngle)
        }
        set{
            if newValue > 0 {
                self.accumVerticalAngle = degTrans(degVal: newValue)
                horizontalTrack?.radius = self.radius * Float(cos(_accumVerticalAngle))
                horizontalChecker.radius = Double(self._radius) * (cos(accumVerticalAngle))
            }
        }
    }
    fileprivate var accumVerticalAngle: Double{ //目前累積移動的圓心角（垂直）
        get{
            return _accumVerticalAngle
        }
        set{
            _accumVerticalAngle = newValue
            horizontalTrack?.radius = self.radius * Float(cos(_accumVerticalAngle))
            horizontalChecker.radius = Double(self._radius) * (cos(accumVerticalAngle))
        }
    }

    init(radius: Float, velocity: Float, sphereCenter: CLLocationCoordinate2D) {
        if radius > 2 {
            self.radius = radius
        }
        if velocity > 0 {
            self.velocity = velocity
        }
        self.sphereCenter = sphereCenter
        self.horizontalTrack = CylinderSpeedBooster(radius: self.radius, velocity: self.velocity, cylinderCenter: self.sphereCenter)
        horizontalTrack?.forSphereUsing = true
        self.horizontalChecker.center = self.sphereCenter
    }
    func horizontalTrans(aircraftLocation: CLLocationCoordinate2D, aircraftHeading: Float, altitude: Float, isCW: Bool)-> Dictionary< String , Float>{
        if !isContinuous() {
            accumVerticalAngle = expectElevation(altitude: altitude )
            isSlowStart = false
        }
        return (horizontalTrack?.horizontalTrans(aircraftLocation: aircraftLocation, aircraftHeading: aircraftHeading, isCW: isCW))!
    }
    func verticalTrans(aircraftLocation: CLLocationCoordinate2D, aircraftHeading: Float , altitude: Float ,up:Bool)-> Dictionary<String, Float>{
        var fineResult:Dictionary<String, Float> = ["rotate": 0, "angle": 0]
        if !isContinuous() {
            // if accumVerticalAngle is up to 90 degree last fine tune and this fine tune try to move down
            if !up && accumVerticalAngle == .pi/2 {
//                accumVerticalAngle = expectElevationByMutiple(aircraftLocation: aircraftLocation, altitude: altitude)
                isStartMoving = true
                isSlowStart = true
                velocityAdjust = Date()
            }
            else {
                accumVerticalAngle = expectElevationByMutiple(aircraftLocation: aircraftLocation, altitude: altitude)
                print("angle Elevation: \(radTrans(radVal:accumVerticalAngle))")
                isStartMoving = false
                isSlowStart = false
                //self.radius = sqrt(pow(Float(distantCal(spotA: aircraftLocation, spotB: sphereCenter)), 2)+pow(altitude, 2))
            }
        }
        if !isStartMoving {
            if distantCal(spotA: aircraftLocation, spotB: sphereCenter) < 0.5 || abs(Double.pi/2 - accumVerticalAngle) < singleElevationRotate {
                isStartMoving = true
                isSlowStart = true
                velocityAdjust = Date()
            }else{
                if isWrongHead(aircraftLocation: aircraftLocation, aircraftHeading: aircraftHeading) {
                    fineResult["rotate"] = toNormalAngle(radTrans(radVal: expectHeading(aircraftLocation: aircraftLocation)))
                    fineResult["angle"] = 1
                }else{
                    isStartMoving = true
                    isSlowStart = true
                    velocityAdjust = Date()
                }
            }
        }

        if isStartMoving {
            if accumVerticalAngle > Double.pi {
                accumVerticalAngle = Double.pi
            }
            if accumVerticalAngle < 0 {
                accumVerticalAngle = 0
            }
            if isSlowStart {
                velocityModifier(secondsToNormal: 0.9)
            }
//            if up {
//                if accumVerticalAngle < Double.pi/2 {
//                    accumVerticalAngle += singleVerticalRotate
//                }
//                if accumVerticalAngle < Double.pi/2 && accumVerticalAngle >= 0 {
//                    fineResult = ["up": velocity * Float(cos(accumVerticalAngle + singleVerticalRotate)), "forward": velocity * Float(sin(accumVerticalAngle + singleVerticalRotate)), "angle": 0]
//                }else{
//                    accumVerticalAngle = Double.pi/2
//                    fineResult =  ["up": 0, "forward": 0, "angle": 0]
//                }
//            }else{
//                if accumVerticalAngle > 0 {
//                    accumVerticalAngle -= singleVerticalRotate
//                }
//                if accumVerticalAngle <= Double.pi/2 && angleOfElevation > 0 {
//                    fineResult =  ["down": velocity * Float(cos(accumVerticalAngle - singleVerticalRotate)), "backward": velocity * Float(sin(accumVerticalAngle - singleVerticalRotate)), "angle": 0]
//                }else{
//                    angleOfElevation = 0
//                    fineResult =  ["down": 0, "backward": 0, "angle": 0]
//                }
//            }
            if up {
                print("accumAngle: \(radTrans(radVal: accumVerticalAngle))")
                if accumVerticalAngle < Double.pi/2 && accumVerticalAngle >= 0 {
                    fineResult = ["up": velocity * Float(cos(singleVelocityTrans)), "forward": velocity * Float(sin(singleVelocityTrans)), "angle": 0]
                }else{
                    accumVerticalAngle = Double.pi/2
                    fineResult =  ["up": 0, "forward": 0, "angle": 0]
                }
                if accumVerticalAngle < Double.pi/2 {
                    accumVerticalAngle += singleElevationRotate
                }
            }else{
                print("accumAngle: \(radTrans(radVal: accumVerticalAngle))")
                if accumVerticalAngle <= Double.pi/2 && accumVerticalAngle > 0 {
                    fineResult =  ["down": velocity * Float(cos(singleVelocityTrans)), "backward": velocity * Float(sin(singleVelocityTrans)), "angle": 0]
                }else{
                    fineResult =  ["down": 0, "backward": 0, "angle": 0]
                }
                if accumVerticalAngle > 0 {
                    accumVerticalAngle -= singleElevationRotate
                }
            }

        }
        return fineResult
    }

    fileprivate func isContinuous()-> Bool{
        let currentTime: Date = Date()
        let result = (currentTime.timeIntervalSince(prevTime) < 0.15) ? true : false
        prevTime = currentTime
        return result
    }

    fileprivate func expectHeading(aircraftLocation: CLLocationCoordinate2D)->Double{
        let calPointA: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: aircraftLocation.latitude, longitude: sphereCenter.longitude)
        var realHead: Double = 0
        if aircraftLocation.latitude < sphereCenter.latitude {
            if aircraftLocation.longitude < sphereCenter.longitude {
                realHead = -Double.pi - asin(-distantCal(spotA: calPointA , spotB: aircraftLocation)/distantCal(spotA: sphereCenter, spotB: aircraftLocation))
            }else{
                realHead = Double.pi - asin(distantCal(spotA: calPointA , spotB: aircraftLocation)/distantCal(spotA: sphereCenter, spotB: aircraftLocation))
            }
        }else{
            if aircraftLocation.longitude < sphereCenter.longitude {
                realHead =  asin(-distantCal(spotA: calPointA , spotB: aircraftLocation)/distantCal(spotA: sphereCenter, spotB: aircraftLocation))
            }else{
                realHead = asin(distantCal(spotA: calPointA , spotB: aircraftLocation)/distantCal(spotA: sphereCenter, spotB: aircraftLocation))
            }
        }
        return realHead
    }

    fileprivate func isWrongHead(aircraftLocation:CLLocationCoordinate2D, aircraftHeading: Float)-> Bool{
        let aircraftCont: Float = aircraftHeading < 0 ? (aircraftHeading + 360) : aircraftHeading
        var expectCont: Float = toNormalAngle(radTrans(radVal: expectHeading(aircraftLocation: aircraftLocation)))
        expectCont = expectCont < 0 ? (expectCont + 360) : expectCont

        if abs(aircraftCont - expectCont) < radTrans(radVal:(horizontalTrack?.rotateSpeed)!) * updateRate {
            return false
        }else if abs(aircraftCont - expectCont) > (360 - radTrans(radVal:(horizontalTrack?.rotateSpeed)!) * updateRate){
            return false
        }else{
            return true
        }

    }

    fileprivate func velocityModifier(secondsToNormal: Double){//做速度調整
        let currentTime: Date = Date()
        let tStep: Double = currentTime.timeIntervalSince(velocityAdjust)
        var modifier = tStep / secondsToNormal
        if modifier < 0.1 {
            modifier = 0.1
        }else if modifier > 1 {
            modifier = 1
        }
        speedModifier = Float(modifier)
    }

    fileprivate func distantCal(spotA: CLLocationCoordinate2D, spotB: CLLocationCoordinate2D)-> Double{
        let tempLocationA:CLLocation = CLLocation(latitude: spotA.latitude, longitude: spotA.longitude)
        let tempLocationB: CLLocation = CLLocation(latitude: spotB.latitude, longitude: spotB.longitude)
        return tempLocationA.distance(from: tempLocationB)
    }

    fileprivate func expectElevation(altitude: Float)-> Double{
        return asin(Double((altitude - 1.5 ) / self.radius))
    }
    fileprivate func expectElevationByMutiple(aircraftLocation: CLLocationCoordinate2D, altitude: Float)-> Double{//依據不同的狀態以不同的方式判斷現在的仰角
        let distanceToCenter: Double = distantCal(spotA: aircraftLocation, spotB: sphereCenter)

        return (Float(distanceToCenter) < self.radius && altitude > 1.5 + self.radius / 2) ? acos(distantCal(spotA: aircraftLocation, spotB: sphereCenter)/Double(self.radius)) : expectElevation(altitude: altitude)
    }

    fileprivate func radTrans(radVal:Double) -> Float{
        return Float(radVal * 180 / Double.pi)
    }
    fileprivate func degTrans(degVal:Float) -> Double{
        return Double(Double(degVal) * Double.pi / 180);
    }
    fileprivate func toNormalAngle(_ angle: Float) -> Float{
        var nVal:Float = angle > 0 ? (angle + 180) : (angle - 180)
        if nVal > 180 {
            nVal = nVal - 360 * round(nVal/360)
        }else if nVal < -180 {
            nVal = nVal + 360 * round(abs(nVal/360))
        }
        return nVal
    }



}
