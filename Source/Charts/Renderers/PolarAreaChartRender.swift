//
//  PolarAreaChartRender.swift
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


open class PolarAreaChartRenderer: DataRenderer
{
    open weak var chart: PolarAreaChartView?
    
    public init(chart: PolarAreaChartView?, animator: Animator?, viewPortHandler: ViewPortHandler?)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.chart = chart
    }
    
    open override func drawData(context: CGContext)
    {
        guard let chart = chart else { return }
        
        let polarData = chart.data
        
        if polarData != nil
        {
            for set in polarData!.dataSets as! [IPieChartDataSet]
            {
                if set.isVisible && set.entryCount > 0
                {
                    drawDataSet(context: context, dataSet: set)
                }
            }
        }
    }
    
    open func calculateMinimumRadiusForSpacedSlice(
        center: CGPoint,
        radius: CGFloat,
        angle: CGFloat,
        arcStartPointX: CGFloat,
        arcStartPointY: CGFloat,
        startAngle: CGFloat,
        sweepAngle: CGFloat) -> CGFloat
    {
        let angleMiddle = startAngle + sweepAngle / 2.0
        
        // Other point of the arc
        let arcEndPointX = center.x + radius * cos((startAngle + sweepAngle) * ChartUtils.Math.FDEG2RAD)
        let arcEndPointY = center.y + radius * sin((startAngle + sweepAngle) * ChartUtils.Math.FDEG2RAD)
        
        // Middle point on the arc
        let arcMidPointX = center.x + radius * cos(angleMiddle * ChartUtils.Math.FDEG2RAD)
        let arcMidPointY = center.y + radius * sin(angleMiddle * ChartUtils.Math.FDEG2RAD)
        
        // This is the base of the contained triangle
        let basePointsDistance = sqrt(
            pow(arcEndPointX - arcStartPointX, 2) +
                pow(arcEndPointY - arcStartPointY, 2))
        
        // After reducing space from both sides of the "slice",
        //   the angle of the contained triangle should stay the same.
        // So let's find out the height of that triangle.
        let containedTriangleHeight = (basePointsDistance / 2.0 *
            tan((180.0 - angle) / 2.0 * ChartUtils.Math.FDEG2RAD))
        
        // Now we subtract that from the radius
        var spacedRadius = radius - containedTriangleHeight
        
        // And now subtract the height of the arc that's between the triangle and the outer circle
        spacedRadius -= sqrt(
            pow(arcMidPointX - (arcEndPointX + arcStartPointX) / 2.0, 2) +
                pow(arcMidPointY - (arcEndPointY + arcStartPointY) / 2.0, 2))
        
        return spacedRadius
    }
    
    /// Calculates the sliceSpace to use based on visible values and their size compared to the set sliceSpace.
    open func getSliceSpace(dataSet: IPieChartDataSet) -> CGFloat
    {
        guard
            dataSet.automaticallyDisableSliceSpacing,
            let viewPortHandler = self.viewPortHandler,
            let data = chart?.data as? PieChartData
            else { return dataSet.sliceSpace }
        
        let spaceSizeRatio = dataSet.sliceSpace / min(viewPortHandler.contentWidth, viewPortHandler.contentHeight)
        let minValueRatio = dataSet.yMin / data.yValueSum * 2.0
        
        let sliceSpace = spaceSizeRatio > CGFloat(minValueRatio)
            ? 0.0
            : dataSet.sliceSpace
        
        return sliceSpace
    }
    
    open func drawDataSet(context: CGContext, dataSet: IPieChartDataSet)
    {
        guard
            let chart = chart,
            let animator = animator
            else {return }
        
        var angle: CGFloat = 0.0
        let rotationAngle = chart.rotationAngle
        
        let phaseX = animator.phaseX
        let phaseY = animator.phaseY
        
        let entryCount = dataSet.entryCount
        var drawAngle = chart.maxAngle / CGFloat(entryCount)
        let center = chart.centerCircleBox
        var maxRadius = chart.radius
        let userInnerRadius = 0.0
        
        var visibleAngleCount = 0
        for j in 0 ..< entryCount
        {
            guard let e = dataSet.entryForIndex(j) else { continue }
            if ((abs(e.y) > DBL_EPSILON))
            {
                visibleAngleCount += 1
            }
        }
        
        let sliceSpace = visibleAngleCount <= 1 ? 0.0 : getSliceSpace(dataSet: dataSet)
        
        context.saveGState()
        
        for j in 0 ..< entryCount
        {
            var radius = chart.drawRadius[j]
            let sliceAngle = drawAngle
            var innerRadius = userInnerRadius
            
            guard let e = dataSet.entryForIndex(j) else { continue }
            
            // draw only if the value is greater than zero
            if (abs(e.y) > DBL_EPSILON)
            {
                if !chart.needsHighlight(index: j)
                {
                    let accountForSliceSpacing = sliceSpace > 0.0 && sliceAngle <= 180.0
                    
                    context.setFillColor(dataSet.color(atIndex: j).cgColor)
                    
                    let sliceSpaceAngleOuter = visibleAngleCount == 1 ?
                        0.0 :
                        sliceSpace / (ChartUtils.Math.FDEG2RAD * radius)
                    let startAngleOuter = rotationAngle + (angle + sliceSpaceAngleOuter / 2.0) * CGFloat(phaseY)
                    var sweepAngleOuter = (sliceAngle - sliceSpaceAngleOuter) * CGFloat(phaseY)
                    if sweepAngleOuter < 0.0
                    {
                        sweepAngleOuter = 0.0
                    }
                    
                    let arcStartPointX = center.x + radius * cos(startAngleOuter * ChartUtils.Math.FDEG2RAD)
                    let arcStartPointY = center.y + radius * sin(startAngleOuter * ChartUtils.Math.FDEG2RAD)
                    
                    let path = CGMutablePath()
                    
                    path.move(to: CGPoint(x: arcStartPointX,
                                          y: arcStartPointY))
                    
                    path.addRelativeArc(center: center, radius: radius, startAngle: startAngleOuter * ChartUtils.Math.FDEG2RAD, delta: sweepAngleOuter * ChartUtils.Math.FDEG2RAD)
                    
                    if accountForSliceSpacing
                    {
                        let angleMiddle = startAngleOuter + sweepAngleOuter / 2.0
                        
                        let sliceSpaceOffset =
                            calculateMinimumRadiusForSpacedSlice(
                                center: center,
                                radius: radius,
                                angle: sliceAngle * CGFloat(phaseY),
                                arcStartPointX: arcStartPointX,
                                arcStartPointY: arcStartPointY,
                                startAngle: startAngleOuter,
                                sweepAngle: sweepAngleOuter)
                        
                        let arcEndPointX = center.x + sliceSpaceOffset * cos(angleMiddle * ChartUtils.Math.FDEG2RAD)
                        let arcEndPointY = center.y + sliceSpaceOffset * sin(angleMiddle * ChartUtils.Math.FDEG2RAD)
                        
                        path.addLine(
                            to: CGPoint(
                                x: arcEndPointX,
                                y: arcEndPointY))
                    }
                    else
                    {
                        path.addLine(to: center)
                    }
                    
                    
                    path.closeSubpath()
                    
                    context.beginPath()
                    context.addPath(path)
                    context.fillPath(using: .evenOdd)
                }
            }
            
            angle += sliceAngle * CGFloat(phaseX)
        }
        
        context.restoreGState()
    }
    
    open override func drawValues(context: CGContext)
    {
        guard
            let chart = chart,
            let data = chart.data,
            let animator = animator
            else { return }
        
        let center = chart.centerCircleBox
        
        let rotationAngle = chart.rotationAngle
        var drawAngles = chart.absoluteAngle
        var absoluteAngles = chart.absoluteAngles
        
        let phaseX = animator.phaseX
        let phaseY = animator.phaseY
        
        var dataSets = data.dataSets
        
        let yValueSum = (data as! PieChartData).yValueSum
        
        let drawEntryLabels = chart.isDrawEntryLabelsEnabled
        let usePercentValuesEnabled = chart.usePercentValuesEnabled
        let entryLabelColor = chart.entryLabelColor
        let entryLabelFont = chart.entryLabelFont
        
        var angle: CGFloat = 0.0
        var xIndex = 0
        
        context.saveGState()
        defer { context.restoreGState() }
        
        for i in 0 ..< dataSets.count
        {
            guard let dataSet = dataSets[i] as? IPieChartDataSet else { continue }
            
            let drawValues = dataSet.isDrawValuesEnabled
            
            if !drawValues && !drawEntryLabels
            {
                continue
            }
            
            let xValuePosition = dataSet.xValuePosition
            let yValuePosition = dataSet.yValuePosition
            
            let valueFont = dataSet.valueFont
            let entryLabelFont = dataSet.entryLabelFont
            let lineHeight = valueFont.lineHeight
            
            guard let formatter = dataSet.valueFormatter else { continue }
            
            for j in 0 ..< dataSet.entryCount
            {
                // get whole the radius
                var radius = chart.drawRadius[j]
                var labelRadiusOffset = radius / 10.0 * 3.0
                let labelRadius = radius - labelRadiusOffset
                
                guard let e = dataSet.entryForIndex(j) else { continue }
                let pe = e as? PieChartDataEntry
                
                if xIndex == 0
                {
                    angle = 0.0
                }
                else
                {
                    angle = absoluteAngles[xIndex - 1] * CGFloat(phaseX)
                }
                
                let sliceAngle = drawAngles
                let sliceSpace = getSliceSpace(dataSet: dataSet)
                let sliceSpaceMiddleAngle = sliceSpace / (ChartUtils.Math.FDEG2RAD * labelRadius)
                
                // offset needed to center the drawn text in the slice
                let angleOffset = (sliceAngle - sliceSpaceMiddleAngle / 2.0) / 2.0
                
                angle = angle + angleOffset
                
                let transformedAngle = rotationAngle + angle * CGFloat(phaseY)
                
                let value = usePercentValuesEnabled ? e.y / yValueSum * 100.0 : e.y
                let valueText = formatter.stringForValue(
                    value,
                    entry: e,
                    dataSetIndex: i,
                    viewPortHandler: viewPortHandler)
                
                let sliceXBase = cos(transformedAngle * ChartUtils.Math.FDEG2RAD)
                let sliceYBase = sin(transformedAngle * ChartUtils.Math.FDEG2RAD)
                
                let drawXOutside = drawEntryLabels && xValuePosition == .outsideSlice
                let drawYOutside = drawValues && yValuePosition == .outsideSlice
                let drawXInside = drawEntryLabels && xValuePosition == .insideSlice
                let drawYInside = drawValues && yValuePosition == .insideSlice
                
                let valueTextColor = dataSet.valueTextColorAt(j)
                let entryLabelColor = dataSet.entryLabelColor
                
                if drawXOutside || drawYOutside
                {
                    let valueLineLength1 = dataSet.valueLinePart1Length
                    let valueLineLength2 = dataSet.valueLinePart2Length
                    let valueLinePart1OffsetPercentage = dataSet.valueLinePart1OffsetPercentage
                    
                    var pt2: CGPoint
                    var labelPoint: CGPoint
                    var align: NSTextAlignment
                    
                    var line1Radius: CGFloat
                    
                    line1Radius = radius * valueLinePart1OffsetPercentage
                    
                    let polyline2Length = dataSet.valueLineVariableLength
                        ? labelRadius * valueLineLength2 * abs(sin(transformedAngle * ChartUtils.Math.FDEG2RAD))
                        : labelRadius * valueLineLength2
                    
                    let pt0 = CGPoint(
                        x: line1Radius * sliceXBase + center.x,
                        y: line1Radius * sliceYBase + center.y)
                    
                    let pt1 = CGPoint(
                        x: labelRadius * (1 + valueLineLength1) * sliceXBase + center.x,
                        y: labelRadius * (1 + valueLineLength1) * sliceYBase + center.y)
                    
                    if transformedAngle.truncatingRemainder(dividingBy: 360.0) >= 90.0 && transformedAngle.truncatingRemainder(dividingBy: 360.0) <= 270.0
                    {
                        pt2 = CGPoint(x: pt1.x - polyline2Length, y: pt1.y)
                        align = .right
                        labelPoint = CGPoint(x: pt2.x - 5, y: pt2.y - lineHeight)
                    }
                    else
                    {
                        pt2 = CGPoint(x: pt1.x + polyline2Length, y: pt1.y)
                        align = .left
                        labelPoint = CGPoint(x: pt2.x + 5, y: pt2.y - lineHeight)
                    }
                    
                    if dataSet.valueLineColor != nil
                    {
                        context.setStrokeColor(dataSet.valueLineColor!.cgColor)
                        context.setLineWidth(dataSet.valueLineWidth)
                        
                        context.move(to: CGPoint(x: pt0.x, y: pt0.y))
                        context.addLine(to: CGPoint(x: pt1.x, y: pt1.y))
                        context.addLine(to: CGPoint(x: pt2.x, y: pt2.y))
                        
                        context.drawPath(using: CGPathDrawingMode.stroke)
                    }
                    
                    if drawXOutside && drawYOutside
                    {
                        ChartUtils.drawText(
                            context: context,
                            text: valueText,
                            point: labelPoint,
                            align: align,
                            attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: valueTextColor]
                        )
                        
                        if j < data.entryCount && pe?.label != nil
                        {
                            ChartUtils.drawText(
                                context: context,
                                text: pe!.label!,
                                point: CGPoint(x: labelPoint.x, y: labelPoint.y + lineHeight),
                                align: align,
                                attributes: [
                                    NSFontAttributeName: entryLabelFont ?? valueFont,
                                    NSForegroundColorAttributeName: entryLabelColor ?? valueTextColor]
                            )
                        }
                    }
                    else if drawXOutside
                    {
                        if j < data.entryCount && pe?.label != nil
                        {
                            ChartUtils.drawText(
                                context: context,
                                text: pe!.label!,
                                point: CGPoint(x: labelPoint.x, y: labelPoint.y + lineHeight / 2.0),
                                align: align,
                                attributes: [
                                    NSFontAttributeName: entryLabelFont ?? valueFont,
                                    NSForegroundColorAttributeName: entryLabelColor ?? valueTextColor]
                            )
                        }
                    }
                    else if drawYOutside
                    {
                        ChartUtils.drawText(
                            context: context,
                            text: valueText,
                            point: CGPoint(x: labelPoint.x, y: labelPoint.y + lineHeight / 2.0),
                            align: align,
                            attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: valueTextColor]
                        )
                    }
                }
                
                if drawXInside || drawYInside
                {
                    // calculate the text position
                    let x = labelRadius * sliceXBase + center.x
                    let y = labelRadius * sliceYBase + center.y - lineHeight
                    
                    if drawXInside && drawYInside
                    {
                        ChartUtils.drawText(
                            context: context,
                            text: valueText,
                            point: CGPoint(x: x, y: y),
                            align: .center,
                            attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: valueTextColor]
                        )
                        
                        if j < data.entryCount && pe?.label != nil
                        {
                            ChartUtils.drawText(
                                context: context,
                                text: pe!.label!,
                                point: CGPoint(x: x, y: y + lineHeight),
                                align: .center,
                                attributes: [
                                    NSFontAttributeName: entryLabelFont ?? valueFont,
                                    NSForegroundColorAttributeName: entryLabelColor ?? valueTextColor]
                            )
                        }
                    }
                    else if drawXInside
                    {
                        if j < data.entryCount && pe?.label != nil
                        {
                            ChartUtils.drawText(
                                context: context,
                                text: pe!.label!,
                                point: CGPoint(x: x, y: y + lineHeight / 2.0),
                                align: .center,
                                attributes: [
                                    NSFontAttributeName: entryLabelFont ?? valueFont,
                                    NSForegroundColorAttributeName: entryLabelColor ?? valueTextColor]
                            )
                        }
                    }
                    else if drawYInside
                    {
                        ChartUtils.drawText(
                            context: context,
                            text: valueText,
                            point: CGPoint(x: x, y: y + lineHeight / 2.0),
                            align: .center,
                            attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: valueTextColor]
                        )
                    }
                }
                
                xIndex += 1
            }
        }
    }
    
    open override func drawExtras(context: CGContext)
    {
        drawCenterText(context: context)
    }
    
    /// draws the description text in the center of the pie chart makes most sense when center-hole is enabled
    fileprivate func drawCenterText(context: CGContext)
    {
        guard
            let chart = chart,
            let centerAttributedText = chart.centerAttributedText
            else { return }
        
        if chart.drawCenterTextEnabled && centerAttributedText.length > 0
        {
            let center = chart.centerCircleBox
            let offset = chart.centerTextOffset
            let innerRadius = chart.radius
            
            let x = center.x + offset.x
            let y = center.y + offset.y
            
            let holeRect = CGRect(
                x: x - innerRadius,
                y: y - innerRadius,
                width: innerRadius * 2.0,
                height: innerRadius * 2.0)
            var boundingRect = holeRect
            
            if chart.centerTextRadiusPercent > 0.0
            {
                boundingRect = boundingRect.insetBy(dx: (boundingRect.width - boundingRect.width * chart.centerTextRadiusPercent) / 2.0, dy: (boundingRect.height - boundingRect.height * chart.centerTextRadiusPercent) / 2.0)
            }
            
            let textBounds = centerAttributedText.boundingRect(with: boundingRect.size, options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine], context: nil)
            
            var drawingRect = boundingRect
            drawingRect.origin.x += (boundingRect.size.width - textBounds.size.width) / 2.0
            drawingRect.origin.y += (boundingRect.size.height - textBounds.size.height) / 2.0
            drawingRect.size = textBounds.size
            
            context.saveGState()
            
            let clippingPath = CGPath(ellipseIn: holeRect, transform: nil)
            context.beginPath()
            context.addPath(clippingPath)
            context.clip()
            
            centerAttributedText.draw(with: drawingRect, options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine], context: nil)
            
            context.restoreGState()
        }
    }
}
