//
//  CircularLocationTransform.swift
//  placeCalculator
//
//  Created by IUILAB on 2016/11/8.
//  Copyright © 2016年 IUILAB. All rights reserved.
//

// with accuracy of 6 digit GPS accuracy is 11.1cm
//這個class用來計算飛機在圓座標系的經緯度
import Foundation
import CoreLocation

class CircularLocationTransform{
    fileprivate var _center: CLLocationCoordinate2D? = kCLLocationCoordinate2DInvalid //圓座標的中心點（度）
    fileprivate var curRadius: Double = 3.0 //圓半徑（公尺）
    fileprivate let earthRadius: Double = 6378137 //地球半徑（公尺）
    var center: CLLocationCoordinate2D{
        get{
            return _center!
        }
        set{
            if newValue.latitude < 90 && newValue.longitude < 180 && newValue.latitude > -90 && newValue.longitude > -180{
                _center = newValue
            }
        }
    }
    var radius: Double{
        get{
            return curRadius
        }
        set{
            if newValue > 2.0 { //半徑不得小於2公尺，否則度數變化會太小
                if newValue > 15 {
                    curRadius = 15 //避免問題數值寫入
                }
                else {
                    curRadius = newValue
                }
            }else{
                curRadius = 2.0
            }
        }
    }

    fileprivate var lonModified: Double{
        get{
            return cos(degTrans(degVal: Float((center.latitude)))) //每一條緯度線的長度隨著緯度上升會變短
        }
    }


    func findCirclePoint(radian: Double) -> CLLocationCoordinate2D { //計算柱狀座標系的經緯度座標
        return changeCircleRadius(radian: radian, radius: curRadius)
    }

    func findSpherePoint(radian: Double, tiltAngle: Double) -> CLLocationCoordinate2D{ //計算球狀座標系的經緯度座標
        return changeCircleRadius(radian: radian, radius: curRadius*cos(tiltAngle))
    }

    fileprivate func changeCircleRadius(radian: Double, radius: Double) -> CLLocationCoordinate2D{ //實際計算經緯度的func
        let moidfiedDegree :Dictionary<String, Double> = meterToGPS(distY: (radius*cos(radian)),distX: (radius*sin(radian))) //計算點與圓中心的距離後轉換為度數
        let newPoint : CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: center.latitude + moidfiedDegree["lat"]!, longitude: center.longitude + moidfiedDegree["lon"]!);//圓中心+新的點座標跟圓中心的經緯度數差別 ＝ 新的點座標的經緯度
        return newPoint
    }

    fileprivate func meterToGPS(distY: Double, distX: Double) -> Dictionary<String, Double>{ //把距離轉換為經緯度的度數
        return ["lat": (180/Double.pi)*(distY/earthRadius), "lon": (180/Double.pi)*(distX/(earthRadius * lonModified))]
    }
    fileprivate func radTrans(radVal:Double) -> Float{ //徑度轉換為角度
        return Float(radVal * 180 / Double.pi)
    }
    fileprivate func degTrans(degVal:Float) -> Double{ //角度轉換為徑度
        return Double(Double(degVal) * Double.pi / 180);
    }


}
