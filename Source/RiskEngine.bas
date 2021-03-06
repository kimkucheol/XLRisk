Attribute VB_Name = "RiskEngine"
Option Explicit
Option Base 1

Public UserStopped As Boolean
Dim SimError As Boolean
Dim SimErrorMsg As String

Private Const ChartHeight = 22 'rows
Private Const ChartWidth = 10 'columns

Public Sub SimIteration(Iter As Integer, RiskInputs As Collection, RiskOutputs As Collection, OutSheet As Worksheet)
    Dim R As Range
    Dim Cell As Range
    Dim Item As Variant
      
    On Error GoTo SSError
        
    'Recalculate
    Application.Calculate
      
    'Produce Output
    Set R = OutSheet.Range("A3").Offset(Iter)
    R = Iter
    Set R = R.Offset(0, 1)
    ' Inputs
    For Each Cell In RiskInputs
        R = Cell
        Set R = R.Offset(0, 1)
    Next Cell
    
    'Outputs
    For Each Item In RiskOutputs
        R = Item(2)
        Set R = R.Offset(0, 1)
    Next Item
    Exit Sub
SSError:
      SimError = True
  SimErrorMsg = "Error in simulation iteration"
End Sub

Public Sub Simulate()
    Dim OutSheet As Worksheet
    Dim AppCalculation
    Dim RiskInputs As Collection
    Dim RiskOutputs As Collection
    Dim XLRisk As Worksheet
    Dim Iterations As Integer
    Dim Iter As Integer
    Dim OldProduceRandomSample As Boolean
    Dim Seed As Double
    
    ' Save ProduceRandomSample
    OldProduceRandomSample = ProduceRandomSample
    
    ' Save Calculation Mode
    AppCalculation = Application.Calculation
    Application.Calculation = xlCalculationManual
    
    On Error GoTo RestoreExcel
        
    Set XLRisk = SetUpXLRisk
    '  Stop Screen Updating?
    Application.ScreenUpdating = XLRisk.Range("ScreenUpdate")
    Application.Cursor = xlWait
    
    Iterations = XLRisk.Range("Iterations")
    
    Set OutSheet = CreateOutputSheet
    
    Set RiskInputs = New Collection
    CollectRiskInputs RiskInputs
    If RiskInputs.Count = 0 Then
        MsgBox "No risk inputs defined", Title:="XLRisk simulation error"
        GoTo RestoreExcel
    End If
    
    Set RiskOutputs = New Collection
    CollectRiskOutputs RiskOutputs
    If RiskOutputs.Count = 0 Then
        MsgBox "No risk outputs defined", Title:="XLRisk simulation error"
        GoTo RestoreExcel
    End If
        
    InitialiseResults RiskInputs, RiskOutputs, OutSheet
    
    'Perform simulation
    UserStopped = False
    ProduceRandomSample = True
    Application.CalculateFull
    
    'Randomize
    Seed = XLRisk.Range("Seed")
    If Seed <> 0 Then
        'https://stackoverflow.com/questions/16589180/visual-basic-random-number-with-seed-but-in-reverse
        Rnd (-1)
        Randomize (Seed)
    Else
        Randomize
    End If
    
    For Iter = 1 To Iterations
        If SimError Then
            SimError = False
            MsgBox SimErrorMsg
            Exit For
        End If
        SimIteration Iter, RiskInputs, RiskOutputs, OutSheet
        DoEvents
        'Check whether to Stop
        If UserStopped Then
            UserStopped = False
            MsgBox "The simulation was interrupted"
            Exit For
        End If
        Application.StatusBar = "Iteration: " & CStr(Iter) & "/" & CStr(Iterations)
    Next Iter
    
    OutSheet.Range("A3").CurrentRegion.Columns.AutoFit
    ' Produce Statistics
    ProduceStatistics Iterations, RiskOutputs, OutSheet
    ' Calculate before producing the graphs
    Application.Calculate
    ' Produce Cumulative Distributions
    ProduceCumulativeDistributions Iterations, RiskOutputs, OutSheet
    ' Produce histograms only if Excel version > 16
    If Val(Application.Version) >= 16 Then ProduceHistograms Iterations, RiskOutputs, OutSheet
    OutSheet.Activate
RestoreExcel:
    'Restore ProduceRandomSample
    ProduceRandomSample = OldProduceRandomSample
    
    'Restore Calculation Mode
    Application.Calculation = AppCalculation
    Application.CalculateFull
    
    ' Restore Status Bar
    Application.StatusBar = False
    
    Application.ScreenUpdating = True
    Application.Cursor = xlDefault
End Sub


Public Sub InitialiseResults(RiskInputs As Collection, RiskOutputs As Collection, WS As Worksheet)
    Dim ER, OutRanges, OutRange As Range
    Dim Cell As Range
    Dim Curr As Range
    Dim I As Integer
    
    With WS
        .Range("B1") = "Inputs"
        .Range("A3") = "Iterations"
    End With
      
    '  Setup risk inputs
    Set Curr = WS.Range("B2")
    For Each Cell In RiskInputs
        Curr = NameOrAddress(Cell)
        Curr.Offset(1, 0) = Right(Cell.Formula, Len(Cell.Formula) - 1)
        Set Curr = Curr.Offset(0, 1)
    Next Cell
    'Format Input
    With Range(WS.Range("B1"), WS.Range("B1").Offset(0, RiskInputs.Count - 1))
        If RiskInputs.Count > 1 Then .Merge
        .Font.Bold = True
        .HorizontalAlignment = xlCenter
    End With
    
    '   Setup risk outputs
    Curr.Offset(-1, 0) = "Outputs"
    Curr.Offset(2).Name = "OutputResults"
    For I = 1 To RiskOutputs.Count
        Set Cell = RiskOutputs(I)(2)
        Curr = QuoteIfNeeded(Cell.Parent.Name) & "!" & Cell.Address
        Curr.Offset(1, 0) = RiskOutputs(I)(1)
        Set Curr = Curr.Offset(0, 1)
    Next I
    'Format Output
    With Range(WS.Range("B1").Offset(0, 1), WS.Range("B1").Offset(0, RiskOutputs.Count))
        If RiskOutputs.Count > 1 Then .Merge
        .Font.Bold = True
        .HorizontalAlignment = xlCenter
    End With
    
    '   Setup Simulation Statistics
    Set Curr = Curr.Offset(0, 2)
    Curr.Offset(-1, 0) = "Simulation Statistics"
    Curr.Offset(2, -1).Name = "SimStats"
    For I = 1 To RiskOutputs.Count
        Set Cell = RiskOutputs(I)(2)
        Curr = QuoteIfNeeded(Cell.Parent.Name) & "!" & Cell.Address
        Curr.Offset(1, 0) = RiskOutputs(I)(1)
        Set Curr = Curr.Offset(0, 1)
    Next I
    'Format Simulation Results
    With Range(WS.Range("SimStats").Offset(-3), WS.Range("SimStats").Offset(-3, RiskOutputs.Count))
        If RiskOutputs.Count > 1 Then .Merge
        .Font.Bold = True
        .HorizontalAlignment = xlCenter
    End With
    
    With WS.Range("B2").CurrentRegion
        .Columns.AutoFit
        .HorizontalAlignment = xlCenter
    End With
    
    '  Setup Output Cumulative Distributions
    Set Curr = Curr.Offset(0, 1)
    Curr.Offset(-1, 0) = "Output Cumulative Distributions"
    Curr.Offset(1, 0).Name = "OutCumDist"
    With Range(Curr.Offset(-1, 0), Curr.Offset(-1, ChartWidth - 1))
        .Merge
        .Font.Bold = True
        .HorizontalAlignment = xlCenter
    End With
    
    If Val(Application.Version) >= 16 Then
        '  Setup Output Histograms
        Set Curr = Curr.Offset(0, ChartWidth + 1)
        Curr.Offset(-1, 0) = "Output Distributions"
        Curr.Offset(1, 0).Name = "OutDist"
        With Range(Curr.Offset(-1, 0), Curr.Offset(-1, ChartWidth - 1))
            .Merge
            .Font.Bold = True
            .HorizontalAlignment = xlCenter
        End With
    End If
End Sub

Sub StatHelper(Cell As Range, StatName As String, StatFormula As String, Address As String)
    Dim I As Integer
    
    Cell = StatName
    Cell.Offset(0, 1).Formula = "=" & StatFormula & "(" & Address & ")"
End Sub

Sub StatAggregateHelper(Cell As Range, StatName As String, FormulaCode As Integer, Address As String)
    Dim I As Integer
    
    Cell = StatName
    Cell.Offset(0, 1).Formula = "=AGGREGATE(" & CStr(FormulaCode) & ",6," & Address & ")"
End Sub

Sub ProduceStatistics(Iterations As Integer, RiskOutputs As Collection, OutSheet As Worksheet)
'  Use the Aggregate Excel function so that stats can be calculated even if the outputs contain a few errors
    Dim FirstOutput As Range
    Dim Cell As Range
    Dim I As Integer
    Dim Address As String
    Dim Count As Integer
    Dim Perc As Integer
    Dim PCount As Integer
    
    Set Cell = OutSheet.Range("OutputResults")
    Set FirstOutput = OutSheet.Range(Cell, Cell.Offset(Iterations - 1))
    Set Cell = OutSheet.Range("SimStats")
    
    Address = FirstOutput.Address(True, False)
    Count = RiskOutputs.Count
    StatAggregateHelper Cell, "Mean", 1, Address
    StatAggregateHelper Cell.Offset(1), "Median", 12, Address
    StatAggregateHelper Cell.Offset(2), "Mode", 13, Address
    StatAggregateHelper Cell.Offset(3), "Std. Deviation", 7, Address
    StatAggregateHelper Cell.Offset(4), "Variance", 10, Address
    StatHelper Cell.Offset(5), "Kurtosis", "KURT", Address
    StatHelper Cell.Offset(6), "Skewness", "Skew", Address
    StatAggregateHelper Cell.Offset(7), "Minimum", 5, Address
    StatAggregateHelper Cell.Offset(8), "Maximum", 4, Address
    Cell.Offset(9) = "Range"
    Cell.Offset(9, 1).Formula = "=" & Cell.Offset(8, 1).Address(False, False) & "-" & Cell.Offset(7, 1).Address(False, False)
    StatHelper Cell.Offset(10), "Count", "Count", Address
    Cell.Offset(11) = "Error Count"
    Cell.Offset(11, 1).FormulaArray = "=COUNT(IF(ISERROR(" & Address & "), 1, """"))"
    Cell.Offset(12) = "Std. Error"
    Cell.Offset(12, 1).Formula = "=" & Cell.Offset(3, 1).Address(False, False) & "/SQRT(" & Cell.Offset(10, 1).Address(False, False) & ")"
    Cell.Offset(13) = "Confidence Level (95%)"
    Cell.Offset(13, 1).Formula = "=CONFIDENCE.T(5%," & Cell.Offset(3, 1).Address(False, False) & "," & Cell.Offset(10, 1).Address(False, False) & ")"
    If Count > 1 Then Range(Cell.Offset(0, 1), Cell.Offset(13, 1)).Copy Range(Cell.Offset(0, 2), Cell.Offset(13, Count))
    'Percentiles
    Cell.Offset(14) = "Percentiles"
    Perc = 0
    For PCount = 1 To 21
        Cell.Offset(14 + PCount) = Perc / 100
        Cell.Offset(14 + PCount).NumberFormat = "0%"
        Cell.Offset(14 + PCount).HorizontalAlignment = xlRight
        Perc = Perc + 5
    Next PCount
    Cell.Offset(15, 1).Formula = "=AGGREGATE(16,6," & Address & "," & Cell.Offset(15).Address(False, True) & ")"
    Range(Cell.Offset(15), Cell.Offset(15 + 20, RiskOutputs.Count)).Name = "Percentiles"
    Cell.Offset(15, 1).Copy Range(Cell.Offset(15, 1), Cell.Offset(15 + 20, Count))
    ' Percent Rank
    Cell.Offset(36) = "Percent Rank"
    Cell.Offset(37) = "Output Cell:"
    Cell.Offset(37, 1) = Cell.Offset(-2, 1)
    ThickBorders Cell.Offset(37, 1)
    Cell.Offset(38) = "Output Name:"
    Address = Range(Cell.Offset(-2, 1), Cell.Offset(-1, RiskOutputs.Count)).Address
    Cell.Offset(38, 1).Formula = "=HLOOKUP(" & Cell.Offset(37, 1).Address & "," & Address & ",2,0)"
    Cell.Offset(39) = "Value:"
    Cell.Offset(39, 1) = Cell.Offset(16, 1) '57th Percentile
    ThickBorders Cell.Offset(39, 1)
    Cell.Offset(40) = "Result:"
    Address = Range(Cell.Offset(-2, 1), Cell.Offset(-2, RiskOutputs.Count)).Address
    Cell.Offset(40, 1) = "=PERCENTRANK.INC(OFFSET(" & FirstOutput.Address & ",0,MATCH(" & Cell.Offset(37, 1).Address _
        & "," & Address & ",0)-1)," & Cell.Offset(39, 1).Address & ")"
    Cell.Offset(40, 1).NumberFormat = "0.00%"
    Range(Cell.Offset(37), Cell.Offset(40)).HorizontalAlignment = xlRight
    With Cell.Offset(37, 1).Validation
        .Add Type:=xlValidateList, AlertStyle:=xlValidAlertStop, Operator:= _
        xlBetween, Formula1:="=" & Address
        .IgnoreBlank = True
        .InCellDropdown = True
        .InputTitle = "Select Output Cell"
        .ShowInput = True
        .ShowError = True
    End With
    Cell.CurrentRegion.Columns.AutoFit
End Sub

Sub ProduceCumulativeDistributions(Iterations As Integer, RiskOutputs As Collection, OutSheet As Worksheet)
    Dim Cell As Range
    Dim I As Integer
    Dim R As Range
    Dim Percentiles As Range
    Dim ChartShape As ChartObject
    Dim NewChart As Chart
    Dim Source As Series
    
    Set Cell = OutSheet.Range("OutCumDist")
    Set Percentiles = OutSheet.Range("Percentiles")
    Set R = Range(Cell, Cell.Offset(ChartHeight - 1, ChartWidth - 1))
    
    OutSheet.Activate
    For I = 1 To RiskOutputs.Count
        Set ChartShape = OutSheet.ChartObjects.Add(Left:=R.Left, Top:=R.Top, Width:=R.Width, Height:=R.Height)
        Set NewChart = ChartShape.Chart
        
        With NewChart
            .ChartType = xlXYScatterSmooth
            .HasLegend = False
            Set Source = .SeriesCollection.NewSeries
            Source.Values = Percentiles.Columns(1)
            Source.XValues = Percentiles.Columns(I + 1)
            .Axes(xlValue).MaximumScale = 1
            If Percentiles.Cells(1, I + 1) > 0 Then
                .Axes(xlCategory).MinimumScale = WorksheetFunction.RoundDown(Percentiles.Cells(1, I + 1), 0)
            End If
            '.Axes(xlCategory).MaximumScale = WorksheetFunction.RoundUp(Percentiles.Cells(21, I + 1), 0)
           .SetElement (msoElementChartTitleAboveChart)
           Set Cell = RiskOutputs(I)(2)
           .ChartTitle.text = "Cum. Distribution of " & RiskOutputs(I)(1) & " (" & QuoteIfNeeded(Cell.Parent.Name) & "!" & Cell.Address & ")"
        End With
        Set R = R.Offset(ChartHeight + 1)
    Next I
    OutSheet.Range("A1").Select
End Sub

Sub ProduceHistograms(Iterations As Integer, RiskOutputs As Collection, OutSheet As Worksheet)
    Dim FirstOutput As Range
    Dim Cell As Range
    Dim I As Integer
    Dim R As Range
    Dim ChartShape As Shape
    Dim NewChart As Chart
    
    On Error Resume Next
    
    Set Cell = OutSheet.Range("OutputResults")
    Set FirstOutput = OutSheet.Range(Cell, Cell.Offset(Iterations - 1))
    Set Cell = OutSheet.Range("OutDist")
    Set R = Range(Cell, Cell.Offset(ChartHeight - 1, ChartWidth - 1))
    
    OutSheet.Activate
    For I = 1 To RiskOutputs.Count
        ' Range needs to be selected
        'https://stackoverflow.com/questions/37912746/vba-why-xlhistogram-does-not-work
        FirstOutput.Offset(0, I - 1).Select
        Set ChartShape = ActiveSheet.Shapes.AddChart2(-1, xlHistogram, R.Left, R.Top, R.Width, R.Height)
        Set NewChart = ChartShape.Chart
        
        Set Cell = RiskOutputs(I)(2)
        With NewChart
           .SetElement (msoElementChartTitleAboveChart)
           .ChartTitle.text = "Distribution of " & RiskOutputs(I)(1) & " (" & QuoteIfNeeded(Cell.Parent.Name) & "!" & Cell.Address & ")"
        End With
        Set R = R.Offset(ChartHeight + 1)
    Next I
    OutSheet.Range("A1").Select
End Sub
