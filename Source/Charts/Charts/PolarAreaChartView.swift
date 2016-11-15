//
//  PolarAreaChartView.swift
//  Charts
//
//  Created by leonardo on 11/15/16.
//
//

//
//  PieChartView.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation
import CoreGraphics

#if !os(OSX)
    import UIKit
#endif

/// View that represents a pie chart. Draws cake like slices.
open class PolarAreaChartView: PieChartView
{
    /// rect object that represents the bounds of the piechart, needed for drawing the circle
    fileprivate var _circleBox = CGRect()
    
    /// flag indicating if entry labels should be drawn or not
    fileprivate var _drawEntryLabelsEnabled = true
    
    /// array that holds the width of each pie-slice in degrees
    fileprivate var _drawAngles = [CGFloat]()
    
    /// array that holds the absolute angle in degrees of each slice
    fileprivate var _absoluteAngles = [CGFloat]()
    
    /// if true, the hole inside the chart will be drawn
    fileprivate var _drawHoleEnabled = true
    
    fileprivate var _holeColor: NSUIColor? = NSUIColor.white
    
    /// Sets the color the entry labels are drawn with.
    fileprivate var _entryLabelColor: NSUIColor? = NSUIColor.white
    
    /// Sets the font the entry labels are drawn with.
    fileprivate var _entryLabelFont: NSUIFont? = NSUIFont(name: "HelveticaNeue", size: 13.0)
    
    /// if true, the hole will see-through to the inner tips of the slices
    fileprivate var _drawSlicesUnderHoleEnabled = false
    
    /// if true, the values inside the piechart are drawn as percent values
    fileprivate var _usePercentValuesEnabled = false
    
    /// variable for the text that is drawn in the center of the pie-chart
    fileprivate var _centerAttributedText: NSAttributedString?
    
    /// the offset on the x- and y-axis the center text has in dp.
    fileprivate var _centerTextOffset: CGPoint = CGPoint()
    
    /// indicates the size of the hole in the center of the piechart
    ///
    /// **default**: `0.5`
    fileprivate var _holeRadiusPercent = CGFloat(0.5)
    
    fileprivate var _transparentCircleColor: NSUIColor? = NSUIColor(white: 1.0, alpha: 105.0/255.0)
    
    /// the radius of the transparent circle next to the chart-hole in the center
    fileprivate var _transparentCircleRadiusPercent = CGFloat(0.55)
    
    /// if enabled, centertext is drawn
    fileprivate var _drawCenterTextEnabled = true
    
    fileprivate var _centerTextRadiusPercent: CGFloat = 1.0
    
    /// maximum angle for this pie
    fileprivate var _maxAngle: CGFloat = 360.0
    
    public override init(frame: CGRect)
    {
        super.init(frame: frame)
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    internal override func initialize()
    {
        super.initialize()
        
        renderer = PieChartRenderer(chart: self, animator: _animator, viewPortHandler: _viewPortHandler)
        _xAxis = nil
        
        self.highlighter = PieHighlighter(chart: self)
    }
    
    open override func draw(_ rect: CGRect)
    {
        super.draw(rect)
        
        if _data === nil
        {
            return
        }
        
        let optionalContext = NSUIGraphicsGetCurrentContext()
        guard let context = optionalContext else { return }
        
        renderer!.drawData(context: context)
        
        if (valuesToHighlight())
        {
            renderer!.drawHighlighted(context: context, indices: _indicesToHighlight)
        }
        
        renderer!.drawExtras(context: context)
        
        renderer!.drawValues(context: context)
        
        _legendRenderer.renderLegend(context: context)
        
        drawDescription(context: context)
        
        drawMarkers(context: context)
    }
    
    internal override func calculateOffsets()
    {
        super.calculateOffsets()
        
        // prevent nullpointer when no data set
        if _data === nil
        {
            return
        }
        
        let radius = diameter / 2.0
        
        let c = self.centerOffsets
        
        let shift = (data as? PieChartData)?.dataSet?.selectionShift ?? 0.0
        
        // create the circle box that will contain the pie-chart (the bounds of the pie-chart)
        _circleBox.origin.x = (c.x - radius) + shift
        _circleBox.origin.y = (c.y - radius) + shift
        _circleBox.size.width = diameter - shift * 2.0
        _circleBox.size.height = diameter - shift * 2.0
    }
    
    internal override func calcMinMax()
    {
        calcAngles()
    }
    
    open override func getMarkerPosition(highlight: Highlight) -> CGPoint
    {
        let center = self.centerCircleBox
        var r = self.radius
        
        var off = r / 10.0 * 3.6
        
        if self.isDrawHoleEnabled
        {
            off = (r - (r * self.holeRadiusPercent)) / 2.0
        }
        
        r -= off // offset to keep things inside the chart
        
        let rotationAngle = self.rotationAngle
        
        let entryIndex = Int(highlight.x)
        
        // offset needed to center the drawn text in the slice
        let offset = drawAngles[entryIndex] / 2.0
        
        // calculate the text position
        let x: CGFloat = (r * cos(((rotationAngle + absoluteAngles[entryIndex] - offset) * CGFloat(_animator.phaseY)) * ChartUtils.Math.FDEG2RAD) + center.x)
        let y: CGFloat = (r * sin(((rotationAngle + absoluteAngles[entryIndex] - offset) * CGFloat(_animator.phaseY)) * ChartUtils.Math.FDEG2RAD) + center.y)
        
        return CGPoint(x: x, y: y)
    }
    
    /// calculates the needed angles for the chart slices
    fileprivate func calcAngles()
    {
        _drawAngles = [CGFloat]()
        _absoluteAngles = [CGFloat]()
        
        guard let data = _data else { return }
        
        let entryCount = data.entryCount
        
        _drawAngles.reserveCapacity(entryCount)
        _absoluteAngles.reserveCapacity(entryCount)

        var dataSets = data.dataSets
        
        var cnt = 0
        
        for i in 0 ..< data.dataSetCount
        {
            let set = dataSets[i]
            let entryCount = set.entryCount
            let angle = maxAngle / CGFloat(entryCount)
            for _ in 0 ..< entryCount
            {
                _drawAngles.append(angle)
                if cnt == 0
                {
                    _absoluteAngles.append(_drawAngles[cnt])
                }
                else
                {
                    _absoluteAngles.append(_absoluteAngles[cnt - 1] + _drawAngles[cnt])
                }
                
                cnt += 1
            }
        }
    }
    
    internal override var requiredLegendOffset: CGFloat
    {
        return _legend.font.pointSize * 2.0
    }
    
    internal override var requiredBaseOffset: CGFloat
    {
        return 0.0
    }
    
    open override var radius: CGFloat
    {
        return _circleBox.width / 2.0
    }
    
}
