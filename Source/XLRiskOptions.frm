VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} XLRiskOptions 
   Caption         =   "XLRisk Options"
   ClientHeight    =   3534
   ClientLeft      =   96
   ClientTop       =   432
   ClientWidth     =   4470
   OleObjectBlob   =   "XLRiskOptions.frx":0000
   StartUpPosition =   1  'CenterOwner
End
Attribute VB_Name = "XLRiskOptions"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Private Sub btnCancel_Click()
    Unload Me
End Sub

Private Sub btnOK_Click()
    Dim XLRisk As Worksheet
    Set XLRisk = SetUpXLRisk
    XLRisk.Range("Seed") = CDbl(tbSeed.text)
    XLRisk.Range("Iterations") = CInt(cbIterations.text)
    XLRisk.Range("ScreenUpdate") = cbScreenUpdate.Value
    If ProduceRandomSample <> cbRandomSamples.Value Then
        ProduceRandomSample = cbRandomSamples.Value
        Application.Calculate
    End If
    
    Unload Me
End Sub

Private Sub UserForm_Initialize()
    Dim XLRisk As Worksheet
    Set XLRisk = SetUpXLRisk
    tbSeed.text = CStr(XLRisk.Range("Seed"))
    cbIterations.AddItem (100)
    cbIterations.AddItem (1000)
    cbIterations.AddItem (10000)
    cbIterations.text = CStr(XLRisk.Range("Iterations"))
    cbScreenUpdate.Value = CBool(XLRisk.Range("ScreenUpdate"))
    cbRandomSamples.Value = ProduceRandomSample
End Sub
