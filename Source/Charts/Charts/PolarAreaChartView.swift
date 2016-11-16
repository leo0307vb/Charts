//
//  PolarAreaChartView.swift
//  Charts
//
//  Created by leonardo on 11/16/16.
//
//

import Foundation
import CoreGraphics

#if !os(OSX)
    import UIKit
#endif

/// View that represents a polar chart. Draws cake like slices.
open class PolarAreaChartView: PieRadarChartViewBase
{
    /// rect object that represents the bounds of the polarchart, needed for drawing the circle
    fileprivate var _circleBox = CGRect()
    
    /// flag indicating if entry labels should be drawn or not
    fileprivate var _drawEntryLabelsEnabled = true
    
    /// Sets the color the entry labels are drawn with.
    fileprivate var _entryLabelColor: NSUIColor? = NSUIColor.white
    
    /// Sets the font the entry labels are drawn with.
    fileprivate var _entryLabelFont: NSUIFont? = NSUIFont(name: "HelveticaNeue", size: 13.0)
    
    /// array that holds the width of each polar-slice in degrees
    fileprivate var _drawRadius = [CGFloat]()
    
    /// array that holds the absolute angle in degrees of each slice
    fileprivate var _absoluteAngles = [CGFloat]()
    
    fileprivate var _absoluteAngle:CGFloat = 360
    
    /// if true, the values inside the polarchart are drawn as percent values
    fileprivate var _usePercentValuesEnabled = false
    
    /// variable for the text that is drawn in the center of the polar-chart
    fileprivate var _centerAttributedText: NSAttributedString?
    
    /// the offset on the x- and y-axis the center text has in dp.
    fileprivate var _centerTextOffset: CGPoint = CGPoint()
    
    fileprivate var _transparentCircleColor: NSUIColor? = NSUIColor(white: 1.0, alpha: 105.0/255.0)
    
    /// the radius of the transparent circle next to the chart-hole in the center
    fileprivate var _transparentCircleRadiusPercent = CGFloat(0.55)
    
    /// if enabled, centertext is drawn
    fileprivate var _drawCenterTextEnabled = true
    
    fileprivate var _centerTextRadiusPercent: CGFloat = 1.0
    
    /// maximum angle for this polar
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
        
        renderer = PolarAreaChartRenderer(chart: self, animator: _animator, viewPortHandler: _viewPortHandler)
        _xAxis = nil
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
        
        // create the circle box that will contain the polar-chart (the bounds of the polar-chart)
        _circleBox.origin.x = (c.x - radius) + shift
        _circleBox.origin.y = (c.y - radius) + shift
        _circleBox.size.width = diameter - shift * 2.0
        _circleBox.size.height = diameter - shift * 2.0
    }
    
    internal override func calcMinMax()
    {
        calcRadiusAndAngle()
    }
    
    open override func getMarkerPosition(highlight: Highlight) -> CGPoint
    {
        let center = self.centerCircleBox
        var r = self.radius
        
        var off = r / 10.0 * 3.6
        
        r -= off // offset to keep things inside the chart
        
        let rotationAngle = self.rotationAngle
        
        let entryIndex = Int(highlight.x)
        
        // offset needed to center the drawn text in the slice
        let offset = absoluteAngle / 2.0
        
        // calculate the text position
        let x: CGFloat = (r * cos(((rotationAngle + _absoluteAngle - offset) * CGFloat(_animator.phaseY)) * ChartUtils.Math.FDEG2RAD) + center.x)
        let y: CGFloat = (r * sin(((rotationAngle + _absoluteAngle - offset) * CGFloat(_animator.phaseY)) * ChartUtils.Math.FDEG2RAD) + center.y)
        
        return CGPoint(x: x, y: y)
    }
    
    /// calculates the needed angles for the chart slices
    fileprivate func calcRadiusAndAngle()
    {
        _absoluteAngles = [CGFloat]()
        _drawRadius = [CGFloat]()
        
        guard let data = _data else { return }
        
        let entryCount = data.entryCount
        
        _absoluteAngles.reserveCapacity(entryCount)
        
        _absoluteAngle = maxAngle / CGFloat(entryCount)
        
        let yValueSum = (_data as! PieChartData).yValueSum
        
        var dataSets = data.dataSets
        
        var cnt = 0
        
        for i in 0 ..< data.dataSetCount
        {
            let set = dataSets[i]
            let entryCount = set.entryCount
            var yValues = [Double]()
            for j in 0 ..< entryCount
            {
                guard let e = set.entryForIndex(j) else { continue }
                yValues.append(e.y)
                if cnt == 0
                {
                    _absoluteAngles.append(_absoluteAngle)
                }
                else
                {
                    _absoluteAngles.append(_absoluteAngles[cnt - 1] + _absoluteAngle)
                }
                cnt += 1
            }
            for value in yValues {
                let maxValue = yValues.max()
                let valuePercentage = (100 * value) / maxValue!
                let radiusValue = (CGFloat(valuePercentage) * self.diameter/2)/CGFloat(100)
                _drawRadius.append(radiusValue)
            }
        }
    }
    
    /// Checks if the given index is set to be highlighted.
    open func needsHighlight(index: Int) -> Bool
    {
        // no highlight
        if !valuesToHighlight()
        {
            return false
        }
        
        for i in 0 ..< _indicesToHighlight.count
        {
            // check if the xvalue for the given dataset needs highlight
            if Int(_indicesToHighlight[i].x) == index
            {
                return true
            }
        }
        
        return false
    }
    
    /// This will throw an exception, polarChart has no XAxis object.
    open override var xAxis: XAxis
    {
        fatalError("polarChart has no XAxis")
    }
    
    /// - returns: The index of the DataSet this x-index belongs to.
    open func dataSetIndexForIndex(_ xValue: Double) -> Int
    {
        var dataSets = _data?.dataSets ?? []
        
        for i in 0 ..< dataSets.count
        {
            if (dataSets[i].entryForXValue(xValue, closestToY: Double.nan) !== nil)
            {
                return i
            }
        }
        
        return -1
    }
    
    /// - returns: An integer array of all the different Radius the chart slices
    /// have the angles in the returned array determine how much space (of 360°)
    /// each slice takes
    open var drawRadius: [CGFloat]
    {
        return _drawRadius
    }
    
    /// - returns: The absolute angles of the different chart slices (where the
    /// slices end)
    open var absoluteAngles: [CGFloat]
    {
        return _absoluteAngles
    }
    
    open var absoluteAngle:CGFloat
    {
        return _absoluteAngle
    }
    
    /// the text that is displayed in the center of the polar-chart
    open var centerText: String?
        {
        get
        {
            return self.centerAttributedText?.string
        }
        set
        {
            var attrString: NSMutableAttributedString?
            if newValue == nil
            {
                attrString = nil
            }
            else
            {
                #if os(OSX)
                    let paragraphStyle = NSParagraphStyle.default().mutableCopy() as! NSMutableParagraphStyle
                #else
                    let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                #endif
                paragraphStyle.lineBreakMode = NSLineBreakMode.byTruncatingTail
                paragraphStyle.alignment = .center
                
                attrString = NSMutableAttributedString(string: newValue!)
                attrString?.setAttributes([
                    NSForegroundColorAttributeName: NSUIColor.black,
                    NSFontAttributeName: NSUIFont.systemFont(ofSize: 12.0),
                    NSParagraphStyleAttributeName: paragraphStyle
                    ], range: NSMakeRange(0, attrString!.length))
            }
            self.centerAttributedText = attrString
        }
    }
    
    /// the text that is displayed in the center of the polar-chart
    open var centerAttributedText: NSAttributedString?
        {
        get
        {
            return _centerAttributedText
        }
        set
        {
            _centerAttributedText = newValue
            setNeedsDisplay()
        }
    }
    
    /// Sets the offset the center text should have from it's original position in dp. Default x = 0, y = 0
    open var centerTextOffset: CGPoint
        {
        get
        {
            return _centerTextOffset
        }
        set
        {
            _centerTextOffset = newValue
            setNeedsDisplay()
        }
    }
    
    /// `true` if drawing the center text is enabled
    open var drawCenterTextEnabled: Bool
        {
        get
        {
            return _drawCenterTextEnabled
        }
        set
        {
            _drawCenterTextEnabled = newValue
            setNeedsDisplay()
        }
    }
    
    /// - returns: `true` if drawing the center text is enabled
    open var isDrawCenterTextEnabled: Bool
        {
        get
        {
            return drawCenterTextEnabled
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
    
    /// - returns: The circlebox, the boundingbox of the polar-chart slices
    open var circleBox: CGRect
    {
        return _circleBox
    }
    
    /// - returns: The center of the circlebox
    open var centerCircleBox: CGPoint
    {
        return CGPoint(x: _circleBox.midX, y: _circleBox.midY)
    }
    
    /// The color that the transparent-circle should have.
    ///
    /// **default**: `nil`
    open var transparentCircleColor: NSUIColor?
        {
        get
        {
            return _transparentCircleColor
        }
        set
        {
            _transparentCircleColor = newValue
            setNeedsDisplay()
        }
    }
    
    /// the radius of the transparent circle that is drawn next to the hole in the polarchart in percent of the maximum radius (max = the radius of the whole chart)
    ///
    /// **default**: 0.55 (55%) -> means 5% larger than the center-hole by default
    open var transparentCircleRadiusPercent: CGFloat
        {
        get
        {
            return _transparentCircleRadiusPercent
        }
        set
        {
            _transparentCircleRadiusPercent = newValue
            setNeedsDisplay()
        }
    }
    
    /// set this to true to draw the enrty labels into the polar slices
    @available(*, deprecated: 1.0, message: "Use `drawEntryLabelsEnabled` instead.")
    open var drawSliceTextEnabled: Bool
        {
        get
        {
            return drawEntryLabelsEnabled
        }
        set
        {
            drawEntryLabelsEnabled = newValue
        }
    }
    
    /// - returns: `true` if drawing entry labels is enabled, `false` ifnot
    @available(*, deprecated: 1.0, message: "Use `isDrawEntryLabelsEnabled` instead.")
    open var isDrawSliceTextEnabled: Bool
        {
        get
        {
            return isDrawEntryLabelsEnabled
        }
    }
    
    /// The color the entry labels are drawn with.
    open var entryLabelColor: NSUIColor?
        {
        get { return _entryLabelColor }
        set
        {
            _entryLabelColor = newValue
            setNeedsDisplay()
        }
    }
    
    /// The font the entry labels are drawn with.
    open var entryLabelFont: NSUIFont?
        {
        get { return _entryLabelFont }
        set
        {
            _entryLabelFont = newValue
            setNeedsDisplay()
        }
    }
    
    /// Set this to true to draw the enrty labels into the polar slices
    open var drawEntryLabelsEnabled: Bool
        {
        get
        {
            return _drawEntryLabelsEnabled
        }
        set
        {
            _drawEntryLabelsEnabled = newValue
            setNeedsDisplay()
        }
    }
    
    /// - returns: `true` if drawing entry labels is enabled, `false` ifnot
    open var isDrawEntryLabelsEnabled: Bool
        {
        get
        {
            return drawEntryLabelsEnabled
        }
    }
    
    /// If this is enabled, values inside the polarChart are drawn in percent and not with their original value. Values provided for the ValueFormatter to format are then provided in percent.
    open var usePercentValuesEnabled: Bool
        {
        get
        {
            return _usePercentValuesEnabled
        }
        set
        {
            _usePercentValuesEnabled = newValue
            setNeedsDisplay()
        }
    }
    
    /// - returns: `true` if drawing x-values is enabled, `false` ifnot
    open var isUsePercentValuesEnabled: Bool
        {
        get
        {
            return usePercentValuesEnabled
        }
    }
    
    /// the rectangular radius of the bounding box for the center text, as a percentage of the polar hole
    open var centerTextRadiusPercent: CGFloat
        {
        get
        {
            return _centerTextRadiusPercent
        }
        set
        {
            _centerTextRadiusPercent = newValue
            setNeedsDisplay()
        }
    }
    
    /// The max angle that is used for calculating the polar-circle.
    /// 360 means it's a full polar-chart, 180 results in a half-polar-chart.
    /// **default**: 360.0
    open var maxAngle: CGFloat
        {
        get
        {
            return _maxAngle
        }
        set
        {
            _maxAngle = newValue
            
            if _maxAngle > 360.0
            {
                _maxAngle = 360.0
            }
            
            if _maxAngle < 90.0
            {
                _maxAngle = 90.0
            }
        }
    }
}
