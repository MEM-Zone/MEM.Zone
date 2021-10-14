<#
.SYNOPSIS
    Gets the Windows 11 compatibility.
.DESCRIPTION
    Gets the Windows 11 upgrade compatibility information.
.PARAMETER Summarization
    Specify if the result will be summarized to "Yes" or "No" instead of the full result.
    Avalaible values:
        - "On"
        - "Off"
    Default value: "Off"
.EXAMPLE
    Get-Windows11Compatibility.ps1
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
    Credit to CyberDrain for the original script.
.LINK
    https://www.cyberdrain.com/monitoring-with-powershell-checking-if-your-device-is-compatible-with-windows-11/
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    Windows
.FUNCTIONALITY
    Compatibility Check
#>

## Set script requirements
#Requires -Version 3.0
#Requires -RunAsAdministrator

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false,Position=0)]
    [ValidateNotNullorEmpty()]
    [Alias('Sum')]
    [string]$Summarization = "Off"
)

## Set supported processor models
$SupportedModels = @'
AMD,AMD,3015e
AMD,AMD,3020e
AMD,Athlon™,Gold 3150C
AMD,Athlon™,Gold 3150U
AMD,Athlon™,Silver 3050C
AMD,Athlon™,Silver 3050e
AMD,Athlon™,Silver 3050U
AMD,Athlon™,3000G
AMD,Athlon™,300GE
AMD,Athlon™,300U
AMD,Athlon™,320GE
AMD,Athlon™,Gold 3150G
AMD,Athlon™,Gold 3150GE
AMD,Athlon™,Silver 3050GE
AMD,EPYC™,7232P
AMD,EPYC™,7252
AMD,EPYC™,7262
AMD,EPYC™,7272
AMD,EPYC™,7282
AMD,EPYC™,7302
AMD,EPYC™,7302P
AMD,EPYC™,7352
AMD,EPYC™,7402
AMD,EPYC™,7402P
AMD,EPYC™,7452
AMD,EPYC™,7502
AMD,EPYC™,7502P
AMD,EPYC™,7532
AMD,EPYC™,7542
AMD,EPYC™,7552
AMD,EPYC™,7642
AMD,EPYC™,7662
AMD,EPYC™,7702
AMD,EPYC™,7702P
AMD,EPYC™,7742
AMD,EPYC™,7F32
AMD,EPYC™,7F52
AMD,EPYC™,7F72
AMD,EPYC™,7H12
AMD,EPYC™,72F3
AMD,EPYC™,7313
AMD,EPYC™,7313P
AMD,EPYC™,7343
AMD,EPYC™,73F3
AMD,EPYC™,7413
AMD,EPYC™,7443
AMD,EPYC™,7443P
AMD,EPYC™,7453
AMD,EPYC™,74F3
AMD,EPYC™,7513
AMD,EPYC™,7543
AMD,EPYC™,7543P
AMD,EPYC™,75F3
AMD,EPYC™,7643
AMD,EPYC™,7663
AMD,EPYC™,7713
AMD,EPYC™,7713P
AMD,EPYC™,7763
AMD,Ryzen™ 3,3250C
AMD,Ryzen™ 3,3250U
AMD,Ryzen™ 3,3200G with Radeon™ Vega 8 Graphics
AMD,Ryzen™ 3,3200GE
AMD,Ryzen™ 3,3200U
AMD,Ryzen™ 3,3350U
AMD,Ryzen™ 3,2300X
AMD,Ryzen™ 3,5300U
AMD,Ryzen™ 3,3100
AMD,Ryzen™ 3,3300U
AMD,Ryzen™ 3,4300G
AMD,Ryzen™ 3,4300GE
AMD,Ryzen™ 3,4300U
AMD,Ryzen™ 3,5400U
AMD,Ryzen™ 3 PRO,3200G
AMD,Ryzen™ 3 PRO,3200GE
AMD,Ryzen™ 3 PRO,3300U
AMD,Ryzen™ 3 PRO,4350G
AMD,Ryzen™ 3 PRO,4350GE
AMD,Ryzen™ 3 PRO,4450U
AMD,Ryzen™ 3 PRO,5450U
AMD,Ryzen™ 5,3400G with Radeon™ RX Vega 11 Graphics
AMD,Ryzen™ 5,3400GE
AMD,Ryzen™ 5,3450U
AMD,Ryzen™ 5,3500C
AMD,Ryzen™ 5,3500U
AMD,Ryzen™ 5,3550H
AMD,Ryzen™ 5,3580U Microsoft Surface® Edition
AMD,Ryzen™ 5,2500X
AMD,Ryzen™ 5,2600
AMD,Ryzen™ 5,2600E
AMD,Ryzen™ 5,2600X
AMD,Ryzen™ 5,5500U
AMD,Ryzen™ 5,3500 Processor
AMD,Ryzen™ 5,3600
AMD,Ryzen™ 5,3600X
AMD,Ryzen™ 5,3600XT
AMD,Ryzen™ 5,4600G
AMD,Ryzen™ 5,4500U
AMD,Ryzen™ 5,4600GE
AMD,Ryzen™ 5,4600H
AMD,Ryzen™ 5,4600U
AMD,Ryzen™ 5,5600H
AMD,Ryzen™ 5,5600HS
AMD,Ryzen™ 5,5600U
AMD,Ryzen™ 5,5600X
AMD,Ryzen™ 5 PRO,3400G
AMD,Ryzen™ 5 PRO,3400GE
AMD,Ryzen™ 5 PRO,3500U
AMD,Ryzen™ 5 PRO,2600
AMD,Ryzen™ 5 PRO,3600
AMD,Ryzen™ 5 PRO,4650G
AMD,Ryzen™ 5 PRO,4650GE
AMD,Ryzen™ 5 PRO,4650U
AMD,Ryzen™ 5 PRO,5650U
AMD,Ryzen™ 7,3700C
AMD,Ryzen™ 7,3700U
AMD,Ryzen™ 7,3750H
AMD,Ryzen™ 7,3780U Microsoft Surface® Edition
AMD,Ryzen™ 7,2700
AMD,Ryzen™ 7,2700E Processor
AMD,Ryzen™ 7,2700X
AMD,Ryzen™ 7,5700U
AMD,Ryzen™ 7,3700X
AMD,Ryzen™ 7,3800X
AMD,Ryzen™ 7,3800XT
AMD,Ryzen™ 7,4700G
AMD,Ryzen™ 7,4700GE
AMD,Ryzen™ 7,4700U
AMD,Ryzen™ 7,4800H
AMD,Ryzen™ 7,4800HS
AMD,Ryzen™ 7,4800U
AMD,Ryzen™ 7,5800H
AMD,Ryzen™ 7,5800HS
AMD,Ryzen™ 7,5800U
AMD,Ryzen™ 7,5800
AMD,Ryzen™ 7,5800X
AMD,Ryzen™ 7 PRO,3700U
AMD,Ryzen™ 7 PRO,2700
AMD,Ryzen™ 7 PRO,2700X
AMD,Ryzen™ 7 PRO,4750G
AMD,Ryzen™ 7 PRO,4750GE
AMD,Ryzen™ 7 PRO,4750U
AMD,Ryzen™ 7 PRO,5850U
AMD,Ryzen™ 9,3900 Processor
AMD,Ryzen™ 9,3900X
AMD,Ryzen™ 9,3900XT
AMD,Ryzen™ 9,3950X
AMD,Ryzen™ 9,4900H
AMD,Ryzen™ 9,4900HS
AMD,Ryzen™ 9,5900HS
AMD,Ryzen™ 9,5900HX
AMD,Ryzen™ 9,5980HS
AMD,Ryzen™ 9,5980HX
AMD,Ryzen™ 9,5900
AMD,Ryzen™ 9,5900X
AMD,Ryzen™ 9,5950X
AMD,Ryzen™ 9 PRO,3900
AMD,Ryzen™ Threadripper™,2920X
AMD,Ryzen™ Threadripper™,2950X
AMD,Ryzen™ Threadripper™,2970WX
AMD,Ryzen™ Threadripper™,2990WX
AMD,Ryzen™ Threadripper™,3960X
AMD,Ryzen™ Threadripper™,3970X
AMD,Ryzen™ Threadripper™,3990X
AMD,Ryzen™ Threadripper™ PRO,3945WX
AMD,Ryzen™ Threadripper™ PRO,3955WX
AMD,Ryzen™ Threadripper™ PRO,3975WX
AMD,Ryzen™ Threadripper™ PRO,3995WX
Intel®,Atom®,x6200FE
Intel®,Atom®,x6211E
Intel®,Atom®,x6212RE
Intel®,Atom®,x6413E
Intel®,Atom®,x6414RE
Intel®,Atom®,x6425E
Intel®,Atom®,x6425RE
Intel®,Atom®,x6427FE
Intel®,Celeron®,G4900
Intel®,Celeron®,G4900T
Intel®,Celeron®,G4920
Intel®,Celeron®,G4930
Intel®,Celeron®,G4930E
Intel®,Celeron®,G4930T
Intel®,Celeron®,G4932E
Intel®,Celeron®,G4950
Intel®,Celeron®,J4005
Intel®,Celeron®,J4105
Intel®,Celeron®,J4115
Intel®,Celeron®,N4000
Intel®,Celeron®,N4100
Intel®,Celeron®,3867U
Intel®,Celeron®,4205U
Intel®,Celeron®,4305U
Intel®,Celeron®,4305UE
Intel®,Celeron®,J4025
Intel®,Celeron®,J4125
Intel®,Celeron®,N4020
Intel®,Celeron®,N4120
Intel®,Celeron®,5205U
Intel®,Celeron®,5305U
Intel®,Celeron®,G5900
Intel®,Celeron®,G5900E
Intel®,Celeron®,G5900T
Intel®,Celeron®,G5900TE
Intel®,Celeron®,G5905
Intel®,Celeron®,G5905T
Intel®,Celeron®,G5920
Intel®,Celeron®,G5925
Intel®,Celeron®,J6412
Intel®,Celeron®,J6413
Intel®,Celeron®,N6210
Intel®,Celeron®,N6211
Intel®,Celeron®,N4500
Intel®,Celeron®,N4505
Intel®,Celeron®,N5100
Intel®,Celeron®,N5105
Intel®,Celeron®,6305
Intel®,Celeron®,6305E
Intel®,Core™,i5-10210Y
Intel®,Core™,i5-10310Y
Intel®,Core™,i5-8200Y
Intel®,Core™,i5-8210Y
Intel®,Core™,i5-8310Y
Intel®,Core™,i7-10510Y
Intel®,Core™,i7-8500Y
Intel®,Core™,m3-8100Y
Intel®,Core™,i3-8100
Intel®,Core™,i3-8100B
Intel®,Core™,i3-8100H
Intel®,Core™,i3-8100T
Intel®,Core™,i3-8109U
Intel®,Core™,i3-8140U
Intel®,Core™,i3-8300
Intel®,Core™,i3-8300T
Intel®,Core™,i3-8350K
Intel®,Core™,i5+8400
Intel®,Core™,i5+8500
Intel®,Core™,i5-8257U
Intel®,Core™,i5-8259U
Intel®,Core™,i5-8260U
Intel®,Core™,i5-8269U
Intel®,Core™,i5-8279U
Intel®,Core™,i5-8300H
Intel®,Core™,i5-8400
Intel®,Core™,i5-8400B
Intel®,Core™,i5-8400H
Intel®,Core™,i5-8400T
Intel®,Core™,i5-8500
Intel®,Core™,i5-8500B
Intel®,Core™,i5-8500T
Intel®,Core™,i5-8600
Intel®,Core™,i5-8600K
Intel®,Core™,i5-8600T
Intel®,Core™,i7-8086K
Intel®,Core™,i7-8557U
Intel®,Core™,i7-8559U
Intel®,Core™,i7-8569U
Intel®,Core™,i7-8700
Intel®,Core™,i7-8700B
Intel®,Core™,i7-8700K
Intel®,Core™,i7-8700T
Intel®,Core™,i7-8750H
Intel®,Core™,i7-8850H
Intel®,Core™,i3-8130U
Intel®,Core™,i5-8250U
Intel®,Core™,i5-8350U
Intel®,Core™,i7-8550U
Intel®,Core™,i7-8650U
Intel®,Core™,i3-8145U
Intel®,Core™,i3-8145UE
Intel®,Core™,i5-8265U
Intel®,Core™,i5-8365U
Intel®,Core™,i5-8365UE
Intel®,Core™,i7-8565U
Intel®,Core™,i7-8665U
Intel®,Core™,i7-8665UE
Intel®,Core™,i3-9100
Intel®,Core™,i3-9100E
Intel®,Core™,i3-9100F
Intel®,Core™,i3-9100HL
Intel®,Core™,i3-9100T
Intel®,Core™,i3-9100TE
Intel®,Core™,i3-9300
Intel®,Core™,i3-9300T
Intel®,Core™,i3-9320
Intel®,Core™,i3-9350K
Intel®,Core™,i3-9350KF
Intel®,Core™,i5-9300H
Intel®,Core™,i5-9300HF
Intel®,Core™,i5-9400
Intel®,Core™,i5-9400F
Intel®,Core™,i5-9400H
Intel®,Core™,i5-9400T
Intel®,Core™,i5-9500
Intel®,Core™,i5-9500E
Intel®,Core™,i5-9500F
Intel®,Core™,i5-9500T
Intel®,Core™,i5-9500TE
Intel®,Core™,i5-9600
Intel®,Core™,i5-9600K
Intel®,Core™,i5-9600KF
Intel®,Core™,i5-9600T
Intel®,Core™,i7-9700
Intel®,Core™,i7-9700E
Intel®,Core™,i7-9700F
Intel®,Core™,i7-9700K
Intel®,Core™,i7-9700KF
Intel®,Core™,i7-9700T
Intel®,Core™,i7-9700TE
Intel®,Core™,i7-9750H
Intel®,Core™,i7-9750HF
Intel®,Core™,i7-9850H
Intel®,Core™,i7-9850HE
Intel®,Core™,i7-9850HL
Intel®,Core™,i9-8950HK
Intel®,Core™,i9-9880H
Intel®,Core™,i9-9900
Intel®,Core™,i9-9900K
Intel®,Core™,i9-9900KF
Intel®,Core™,i9-9900KS
Intel®,Core™,i9-9900T
Intel®,Core™,i9-9980HK
Intel®,Core™,i3-10100Y
Intel®,Core™,i3-10110Y
Intel®,Core™,i9-10900X
Intel®,Core™,i9-10920X
Intel®,Core™,i9-10940X
Intel®,Core™,i9-10980XE
Intel®,Core™,i3-10100
Intel®,Core™,i3-10100E
Intel®,Core™,i3-10100F
Intel®,Core™,i3-10100T
Intel®,Core™,i3-10100TE
Intel®,Core™,i3-10105
Intel®,Core™,i3-10105F
Intel®,Core™,i3-10105T
Intel®,Core™,i3-10110U
Intel®,Core™,i3-10300
Intel®,Core™,i3-10300T
Intel®,Core™,i3-10305
Intel®,Core™,i3-10305T
Intel®,Core™,i3-10320
Intel®,Core™,i3-10325
Intel®,Core™,i5-10200H
Intel®,Core™,i5-10210U
Intel®,Core™,i5-10300H
Intel®,Core™,i5-10310U
Intel®,Core™,i5-10400
Intel®,Core™,i5-10400F
Intel®,Core™,i5-10400H
Intel®,Core™,i5-10400T
Intel®,Core™,i5-10500
Intel®,Core™,i5-10500E
Intel®,Core™,i5-10500H
Intel®,Core™,i5-10500T
Intel®,Core™,i5-10500TE
Intel®,Core™,i5-10600
Intel®,Core™,i5-10600K
Intel®,Core™,i5-10600KF
Intel®,Core™,i5-10600T
Intel®,Core™,i7-10510U
Intel®,Core™,i7-10610U
Intel®,Core™,i7-10700
Intel®,Core™,i7-10700E
Intel®,Core™,i7-10700F
Intel®,Core™,i7-10700K
Intel®,Core™,i7-10700KF
Intel®,Core™,i7-10700T
Intel®,Core™,i7-10700TE
Intel®,Core™,i7-10710U
Intel®,Core™,i7-10750H
Intel®,Core™,i7-10810U
Intel®,Core™,i7-10850H
Intel®,Core™,i7-10870H
Intel®,Core™,i7-10875H
Intel®,Core™,i9-10850K
Intel®,Core™,i9-10885H
Intel®,Core™,i9-10900
Intel®,Core™,i9-10900E
Intel®,Core™,i9-10900F
Intel®,Core™,i9-10900K
Intel®,Core™,i9-10900KF
Intel®,Core™,i9-10900T
Intel®,Core™,i9-10900TE
Intel®,Core™,i9-10980HK
Intel®,Core™,i3-1000G1
Intel®,Core™,i3-1000G4
Intel®,Core™,i3-1005G1
Intel®,Core™,i5-1030G4
Intel®,Core™,i5-1030G7
Intel®,Core™,i5-1035G1
Intel®,Core™,i5-1035G4
Intel®,Core™,i5-1035G7
Intel®,Core™,i5-1038NG7
Intel®,Core™,i7-1060G7
Intel®,Core™,i7-1065G7
Intel®,Core™,i7-1068NG7
Intel®,Core™,i3-L13G4
Intel®,Core™,i5-L16G7
Intel®,Core™,i5-11400
Intel®,Core™,i5-11400F
Intel®,Core™,i5-11400T
Intel®,Core™,i5-11500
Intel®,Core™,i5-11500T
Intel®,Core™,i5-11600
Intel®,Core™,i5-11600K
Intel®,Core™,i5-11600KF
Intel®,Core™,i5-11600T
Intel®,Core™,i7-11700
Intel®,Core™,i7-11700F
Intel®,Core™,i7-11700K
Intel®,Core™,i7-11700KF
Intel®,Core™,i7-11700T
Intel®,Core™,i9-11900
Intel®,Core™,i9-11900F
Intel®,Core™,i9-11900K
Intel®,Core™,i9-11900KF
Intel®,Core™,i9-11900T
Intel®,Core™,i3-1110G4
Intel®,Core™,i3-1115G4
Intel®,Core™,i3-1115G4E
Intel®,Core™,i3-1115GRE
Intel®,Core™,i3-1120G4
Intel®,Core™,i3-1125G4
Intel®,Core™,i5-11300H
Intel®,Core™,i5-1130G7
Intel®,Core™,i5-1135G7
Intel®,Core™,i5-1135G7
Intel®,Core™,i5-1140G7
Intel®,Core™,i5-1145G7
Intel®,Core™,i5-1145G7E
Intel®,Core™,i5-1145GRE
Intel®,Core™,i7-11370H
Intel®,Core™,i7-11375H
Intel®,Core™,i7-1160G7
Intel®,Core™,i7-1165G7
Intel®,Core™,i7-1165G7
Intel®,Core™,i7-1180G7
Intel®,Core™,i7-1185G7
Intel®,Core™,i7-1185G7E
Intel®,Core™,i7-1185GRE
Intel®,Pentium®,Gold 4425Y
Intel®,Pentium®,Gold 6500Y
Intel®,Pentium®,Gold G5400
Intel®,Pentium®,Gold G5400T
Intel®,Pentium®,Gold G5420
Intel®,Pentium®,Gold G5420T
Intel®,Pentium®,Gold G5500
Intel®,Pentium®,Gold G5500T
Intel®,Pentium®,Gold G5600
Intel®,Pentium®,Gold G5600T
Intel®,Pentium®,Gold G5620
Intel®,Pentium®,Silver J5005
Intel®,Pentium®,Silver N5000
Intel®,Pentium®,Gold 4417U
Intel®,Pentium®,Gold 5405U
Intel®,Pentium®,Silver J5040
Intel®,Pentium®,Silver N5030
Intel®,Pentium®,Gold 6405U
Intel®,Pentium®,Gold G6400
Intel®,Pentium®,Gold G6400E
Intel®,Pentium®,Gold G6400T
Intel®,Pentium®,Gold G6400TE
Intel®,Pentium®,Gold G6405
Intel®,Pentium®,Gold G6405T
Intel®,Pentium®,Gold G6500
Intel®,Pentium®,Gold G6500T
Intel®,Pentium®,Gold G6505
Intel®,Pentium®,Gold G6505T
Intel®,Pentium®,Gold G6600
Intel®,Pentium®,Gold G6605
Intel®,Pentium®,6805
Intel®,Pentium®,J6426
Intel®,Pentium®,N6415
Intel®,Pentium®,Silver N6000
Intel®,Pentium®,Silver N6005
Intel®,Pentium®,Gold 7505
Intel®,Xeon®,Bronze 3104
Intel®,Xeon®,Bronze 3106
Intel®,Xeon®,Gold 5115
Intel®,Xeon®,Gold 5118
Intel®,Xeon®,Gold 5119T
Intel®,Xeon®,Gold 5120
Intel®,Xeon®,Gold 5120T
Intel®,Xeon®,Gold 5122
Intel®,Xeon®,Gold 6126
Intel®,Xeon®,Gold 6126F
Intel®,Xeon®,Gold 6126T
Intel®,Xeon®,Gold 6128
Intel®,Xeon®,Gold 6130
Intel®,Xeon®,Gold 6130F
Intel®,Xeon®,Gold 6130T
Intel®,Xeon®,Gold 6132
Intel®,Xeon®,Gold 6134
Intel®,Xeon®,Gold 6136
Intel®,Xeon®,Gold 6138
Intel®,Xeon®,Gold 6138F
Intel®,Xeon®,Gold 6138P
Intel®,Xeon®,Gold 6138T
Intel®,Xeon®,Gold 6140
Intel®,Xeon®,Gold 6142
Intel®,Xeon®,Gold 6142F
Intel®,Xeon®,Gold 6144
Intel®,Xeon®,Gold 6146
Intel®,Xeon®,Gold 6148
Intel®,Xeon®,Gold 6148F
Intel®,Xeon®,Gold 6150
Intel®,Xeon®,Gold 6152
Intel®,Xeon®,Gold 6154
Intel®,Xeon®,Platinum 8153
Intel®,Xeon®,Platinum 8156
Intel®,Xeon®,Platinum 8158
Intel®,Xeon®,Platinum 8160
Intel®,Xeon®,Platinum 8160F
Intel®,Xeon®,Platinum 8160T
Intel®,Xeon®,Platinum 8164
Intel®,Xeon®,Platinum 8168
Intel®,Xeon®,Platinum 8170
Intel®,Xeon®,Platinum 8176
Intel®,Xeon®,Platinum 8176F
Intel®,Xeon®,Platinum 8180
Intel®,Xeon®,Silver 4108
Intel®,Xeon®,Silver 4109T
Intel®,Xeon®,Silver 4110
Intel®,Xeon®,Silver 4112
Intel®,Xeon®,Silver 4114
Intel®,Xeon®,Silver 4114T
Intel®,Xeon®,Silver 4116
Intel®,Xeon®,Silver 4116T
Intel®,Xeon®,E-2124
Intel®,Xeon®,E-2124G
Intel®,Xeon®,E-2126G
Intel®,Xeon®,E-2134
Intel®,Xeon®,E-2136
Intel®,Xeon®,E-2144G
Intel®,Xeon®,E-2146G
Intel®,Xeon®,E-2174G
Intel®,Xeon®,E-2176G
Intel®,Xeon®,E-2176M
Intel®,Xeon®,E-2186G
Intel®,Xeon®,E-2186M
Intel®,Xeon®,E-2224
Intel®,Xeon®,E-2224G
Intel®,Xeon®,E-2226G
Intel®,Xeon®,E-2226GE
Intel®,Xeon®,E-2234
Intel®,Xeon®,E-2236
Intel®,Xeon®,E-2244G
Intel®,Xeon®,E-2246G
Intel®,Xeon®,E-2254ME
Intel®,Xeon®,E-2254ML
Intel®,Xeon®,E-2274G
Intel®,Xeon®,E-2276G
Intel®,Xeon®,E-2276M
Intel®,Xeon®,E-2276ME
Intel®,Xeon®,E-2276ML
Intel®,Xeon®,E-2278G
Intel®,Xeon®,E-2278GE
Intel®,Xeon®,E-2278GEL
Intel®,Xeon®,E-2286G
Intel®,Xeon®,E-2286M
Intel®,Xeon®,E-2288G
Intel®,Xeon®,Bronze 3204
Intel®,Xeon®,Bronze 3206R
Intel®,Xeon®,Gold 5215
Intel®,Xeon®,Gold 5215L
Intel®,Xeon®,Gold 5217
Intel®,Xeon®,Gold 5218B
Intel®,Xeon®,Gold 5218N
Intel®,Xeon®,Gold 5218R
Intel®,Xeon®,Gold 5218T
Intel®,Xeon®,Gold 5220
Intel®,Xeon®,Gold 5220R
Intel®,Xeon®,Gold 5220S
Intel®,Xeon®,Gold 5220T
Intel®,Xeon®,Gold 5222
Intel®,Xeon®,Gold 6208U
Intel®,Xeon®,Gold 6209U
Intel®,Xeon®,Gold 6210U
Intel®,Xeon®,Gold 6212U
Intel®,Xeon®,Gold 6222V
Intel®,Xeon®,Gold 6226
Intel®,Xeon®,Gold 6226R
Intel®,Xeon®,Gold 6230
Intel®,Xeon®,Gold 6230N
Intel®,Xeon®,Gold 6230R
Intel®,Xeon®,Gold 6230T
Intel®,Xeon®,Gold 6238
Intel®,Xeon®,Gold 6238L
Intel®,Xeon®,Gold 6238T
Intel®,Xeon®,Gold 6240
Intel®,Xeon®,Gold 6240L
Intel®,Xeon®,Gold 6240R
Intel®,Xeon®,Gold 6240Y
Intel®,Xeon®,Gold 6242
Intel®,Xeon®,Gold 6242R
Intel®,Xeon®,Gold 6244
Intel®,Xeon®,Gold 6246R
Intel®,Xeon®,Gold 6248
Intel®,Xeon®,Gold 6248R
Intel®,Xeon®,Gold 6250
Intel®,Xeon®,Gold 6250L
Intel®,Xeon®,Gold 6252
Intel®,Xeon®,Gold 6252N
Intel®,Xeon®,Gold 6254
Intel®,Xeon®,Gold 6256
Intel®,Xeon®,Gold 6258R
Intel®,Xeon®,Gold 6262V
Intel®,Xeon®,Gold Gold 5218
Intel®,Xeon®,Gold Gold 6238R
Intel®,Xeon®,Gold6246
Intel®,Xeon®,Goldv 6234
Intel®,Xeon®,Platinum 8253
Intel®,Xeon®,Platinum 8256
Intel®,Xeon®,Platinum 8260
Intel®,Xeon®,Platinum 8260L
Intel®,Xeon®,Platinum 8260Y
Intel®,Xeon®,Platinum 8268
Intel®,Xeon®,Platinum 8270
Intel®,Xeon®,Platinum 8276
Intel®,Xeon®,Platinum 8276L
Intel®,Xeon®,Platinum 8280
Intel®,Xeon®,Platinum 8280L
Intel®,Xeon®,Platinum 9221
Intel®,Xeon®,Platinum 9222
Intel®,Xeon®,Platinum 9242
Intel®,Xeon®,Platinum 9282
Intel®,Xeon®,Silver 4208
Intel®,Xeon®,Silver 4209T
Intel®,Xeon®,Silver 4210
Intel®,Xeon®,Silver 4210R
Intel®,Xeon®,Silver 4210T
Intel®,Xeon®,Silver 4214
Intel®,Xeon®,Silver 4214R
Intel®,Xeon®,Silver 4214Y
Intel®,Xeon®,Silver 4215
Intel®,Xeon®,Silver 4215R
Intel®,Xeon®,Silver 4216
Intel®,Xeon®,W-2223
Intel®,Xeon®,W-2225
Intel®,Xeon®,W-2235
Intel®,Xeon®,W-2245
Intel®,Xeon®,W-2255
Intel®,Xeon®,W-2265
Intel®,Xeon®,W-2275
Intel®,Xeon®,W-2295
Intel®,Xeon®,W-3223
Intel®,Xeon®,W-3225
Intel®,Xeon®,W-3235
Intel®,Xeon®,W-3245
Intel®,Xeon®,W-3245M
Intel®,Xeon®,W-3265
Intel®,Xeon®,W-3265M
Intel®,Xeon®,W-3275
Intel®,Xeon®,W-3275M
Intel®,Xeon®,W-10855M
Intel®,Xeon®,W-10885M
Intel®,Xeon®,W-1250
Intel®,Xeon®,W-1250E
Intel®,Xeon®,W-1250P
Intel®,Xeon®,W-1250TE
Intel®,Xeon®,W-1270
Intel®,Xeon®,W-1270E
Intel®,Xeon®,W-1270P
Intel®,Xeon®,W-1270TE
Intel®,Xeon®,W-1290
Intel®,Xeon®,W-1290E
Intel®,Xeon®,W-1290P
Intel®,Xeon®,W-1290T
Intel®,Xeon®,W-1290TE
Intel®,Xeon®,Gold 5315Y
Intel®,Xeon®,Gold 5317
Intel®,Xeon®,Gold 5318N
Intel®,Xeon®,Gold 5318S
Intel®,Xeon®,Gold 5320
Intel®,Xeon®,Gold 5320T
Intel®,Xeon®,Gold 6312U
Intel®,Xeon®,Gold 6314U
Intel®,Xeon®,Gold 6326
Intel®,Xeon®,Gold 6330
Intel®,Xeon®,Gold 6330N
Intel®,Xeon®,Gold 6334
Intel®,Xeon®,Gold 6336Y
Intel®,Xeon®,Gold 6338
Intel®,Xeon®,Gold 6338N
Intel®,Xeon®,Gold 6338T
Intel®,Xeon®,Gold 6342
Intel®,Xeon®,Gold 6346
Intel®,Xeon®,Gold 6348
Intel®,Xeon®,Gold 6354
Intel®,Xeon®,Gold Gold 5318Y
Intel®,Xeon®,Platinum 8351N
Intel®,Xeon®,Platinum 8352S
Intel®,Xeon®,Platinum 8352V
Intel®,Xeon®,Platinum 8352Y
Intel®,Xeon®,Platinum 8358
Intel®,Xeon®,Platinum 8358P
Intel®,Xeon®,Platinum 8360Y
Intel®,Xeon®,Platinum 8368
Intel®,Xeon®,Platinum 8368Q
Intel®,Xeon®,Platinum 8380
Intel®,Xeon®,Silver 4309Y
Intel®,Xeon®,Silver 4310
Intel®,Xeon®,Silver 4310T
Intel®,Xeon®,Silver 4314
Intel®,Xeon®,Silver 4316
Qualcomm®,Snapdragon™,Snapdragon 850
Qualcomm®,Snapdragon™,Snapdragon 7c
Qualcomm®,Snapdragon™,Snapdragon 8c
Qualcomm®,Snapdragon™,Snapdragon 8cx
Qualcomm®,Snapdragon™,Snapdragon 8cx (Gen2)
Qualcomm®,Snapdragon™,Microsoft SQ1
Qualcomm®,Snapdragon™,Microsoft SQ2
'@ | ConvertFrom-CSV -Header 'Manufacturer', 'Series', 'Model'

## Get default error action preference
$DefaultErrorActionPreference = $ErrorActionPreference

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

## Check if the processor model is in the supported list
$ProcessorCheck = (Get-CimInstance -ClassName 'Win32_Processor').Name -split ' ' | ForEach-Object { $SupportedModels | Where-Object -Property 'Model' -eq $_ }

[boolean]$CompatibleProcessor = If (-not [string]::IsNullorWhiteSpace($ProcessorCheck)) { $true } Else { $false }

## Check if TMP is present and do not return an error if Get-Tpm commandlet fails
Try {
    [boolean]$TpmIsPresent = If ((Get-Tpm).TpmPresent) { $true } Else { $false }
}
Catch {
    $ErrorActionPreference = 'SilentlyContinue'
}
Finally {
    $ErrorActionPreference = $DefaultErrorActionPreference
}

## Check if TMP is 2.0 and do not return an error if Get-Tpm commandlet fails
If ($TpmIsPresent) {
    Try {
        [string]$Tpm20Info = (Get-Tpm).ManufacturerVersionFull20
        [boolean]$TpmIs20 = If ( -not [string]::IsNullorWhiteSpace($Tpm20Info) -and $Tpm20Info -notcontains 'not supported') { $true } Else { $false }
    }
    Catch {
        $ErrorActionPreference = 'SilentlyContinue'
    }
    Finally {
        $ErrorActionPreference = $DefaultErrorActionPreference
    }
}

## Check if machine is virtual
$ComputerModel = Get-CimInstance -ClassName 'Win32_ComputerSystemProduct' | Where-Object -Property 'Name' -match 'Virtual'
[boolean]$IsVirtual = If (-not [string]::IsNullorWhiteSpace($ComputerModel)) { $true } Else { $false }

## Check for Compatible TPM
[boolean]$CompatibleTpm = If ($TpmIsPresent -and $TpmIs20) { $true } ElseIf ($IsVirtual -and $TpmIsPresent) { $true } Else { $false }

## Build result object
$Result = [PScustomObject]@{
    'CompatibleTPM'       = $CompatibleTpm
    'CompatibleProcessor' = $CompatibleProcessor
    '64 Bit OS'           = [Environment]::Is64BitOperatingSystem
}

## Return 'Compatible' if all checks have passed ($true) or Return only failed checks ($false) by removing all passed checks from the result object
If ($Result.PSObject.Properties.Value -notContains $false) { $Result = 'Compatible' }
Else {
    ForEach ($Member in $Result.PsObject.Members) {
        If ($Member.MemberType -eq 'NoteProperty' -and $Member.Value -eq $True) { $Result.PsObject.Members.Remove($Member.Name) }
    }
}

## Return result
If ($Summarization -eq 'On') { If ($Result -eq 'Compatible') { $Result = 'Yes' } Else { $Result = 'No' } }
Write-Output -InputObject $Result

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================