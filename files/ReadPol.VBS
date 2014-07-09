'readpol.vbs (c) 2005-2007 martin underscore binder at gmx dot de
'
'cscript readpol.vbs /PolFile:registry.pol [/TxtFile:registry.txt] [/Mode:R|C]
'[/NullChar:"MyNull"] [/MultiSep:"MySep"] [/SameAsValue:"t"] [/BinMarker:"u"] [/HexMarker:"v"]
'[/KeySep:"w"] [/ValueSep:"x"] [/TypeSep:"y"] [/DataSep:"z"] [/NoHex]
'[/L[A|O][:Logfile]] [/H:C|W] [/W[:0|1]] [/MaxLog:x]
'
'See readpol_en.txt/readpol_de.txt for full explanation and usage examples.

'2006/06/19 v1.0    Initial
'2007/03/23 v2.0    Reformatting and lots of comments

Option Explicit
On Error Resume Next

Const ScriptVersion = "2.0"

Dim PolFile, PolStream, PolData, PolHeader, Mode
Dim TxtFile, TxtStream, TxtData
Dim NullChar, MultiSep, SameAsValue
Dim KeySep, ValueSep, TypeSep, DataSep
Dim HexMarker, BinMarker, NoHex
Const adTypeBinary = 1, adTypeText = 2

PolHeader = "PReg" & Chr( 1 ) & String( 3, Chr( 0 ) )   'registry.pol 8 byte header
PolFile = ""    'registry.pol file to read/write
TxtFile = ""    'registry.txt file to read/write
Mode = "R"      'defauld processing mode is "read policy file"

NullChar = "<00>"   'output characters for nul bytes
MultiSep = "<CrLf>" 'output characters for CR/LF

SameAsValue = "<SameAsValue>"   '
KeySep = ":"        'separator between key and value name
ValueSep = "="      'separator between value name and value type
TypeSep = ":"       'separator between value type and value data
DataSep = " "       'separator between hex and ascii/decimal value data
HexMarker = "0x"    'data notation is hex
BinMarker = "0b"    'data notation is binary
NoHex = False       'if true, only ascii/decimal notation is used

'common variables
Const Done = "Finished processing."
Dim Args, Home, Self, LogFile, LogAppend, LogScreen, MaxLog
Dim Once, ScriptRegKey, ScriptRootKey, ScriptDate, ExecDate 'execution control
Dim SourceDir, TargetDir, ScriptRC, RC, WshHost 'script environment specific
Dim d, f, g, h, i, j, k, l, m, o, p, q, t, u, v, w, x, y, z  'files, counters
Dim a(), b(), c()                                      'array, list

'common objects
Dim fso, oWSH, oNet, oSys, oIE, HKey
Dim ComputerName, UserName, DomainName
Set fso = CreateObject( "Scripting.FileSystemObject" )
Set oNet = CreateObject( "WScript.Network" )
Set oWSH = CreateObject( "WScript.Shell" )
Set HKey    = CreateObject( "Scripting.Dictionary" )
ComputerName    = oNet.ComputerName
UserName        = oNet.UserName
DomainName      = oNet.UserDomain

'default variables, paths and flags
WshHost = UCase( fso.GetBaseName( WScript.FullName ) )
Home = fso.GetParentFolderName( WScript.ScriptFullName )
Self = fso.GetBaseName( WScript.ScriptName )
LogFile = ""
LogAppend = True
LogScreen = True
MaxLog = 100000

'process command line arguments
For Each t In WScript.Arguments
    Args = Args & " " & t   'rebuild Args variable to log all arguments
    u = Split( t, ":", 2, vbTextCompare )   'a colon separates param name and value
    u( 0 ) = UCase( Mid( u( 0 ), 2 ) )      'the param name is prefixed with anything (commonly "/")
    If UBound( u ) > 0 Then u( 1 ) = oWSH.ExpandEnvironmentStrings( u( 1 ) )    'if a param value is present, expand env vars
    Select Case u( 0 )
        Case "H"    'define scripting host to use
            If InStr( 1, u( 1 ), "W", vbTextCompare ) = 1 Then WshHost = "WSCRIPT"
            If InStr( 1, u( 1 ), "C", vbTextCompare ) = 1 Then WshHost = "CSCRIPT"
        Case "L"    'enable logging and define logfile
            LogFile = fso.BuildPath( Home, Self & "_" & Computername & ".LOG" )
            If UBound( u ) > 0 Then LogFile = u( 1 )
        Case "LA"   'append to existing logfile
            LogFile = fso.BuildPath( Home, Self & "_" & Computername & ".LOG" )
            If UBound( u ) > 0 Then LogFile = u( 1 )
            LogAppend = True
        Case "LO"   'overwrite existing logfile
            LogFile = fso.BuildPath( Home, Self & "_" & Computername & ".LOG" )
            If UBound( u ) > 0 Then LogFile = u( 1 )
            LogAppend = False
        Case "W"    'enable/disable screen output
            LogScreen = True
            If UBound( u ) > 0 Then LogScreen = ( u( 1 ) <> 0 )
        Case "?"    'provide some help
            Set f = fso.OpenTextFile( WScript.ScriptFullName, 1 )
            Do While Not f.AtEndOfStream
                l = f.ReadLine
                If l = "" Then Exit Do
                WScript.Echo Mid( l, 2 )
            Loop 'While Not f.AtEndOfStream
            f.Close
            WScript.Quit
        Case Else   'tricky - param name becomes var name, param value becomes var content
            If UBound( u ) > 0 Then
                If IsNumeric( u( 1 ) ) Then 'if param value is numeric, just assign
                    Execute u( 0 ) & " = " & u( 1 )
                Else                        'if param value is string, put quotes around
                    Execute u( 0 ) & " = " & """" &  u( 1 ) & """"
                End If 'IsNumeric( u( 1 ) )
            Else    'if no param value, var becomes true
                Execute u( 0 ) & " = True"
            End If 'UBound( u ) > 0
    End Select 'Case u( 0 )
Next 't In WScript.Arguments

'change scripting host if required
If InStr( 1, WScript.FullName, WshHost, vbTextCompare ) = 0 Then WScript.Quit oWSH.Run( WshHost & " " & """" & WScript.ScriptFullName & """" & Args, , True )

'initialize log file
If LogFile <> "" Then
    err.Clear
    If InStr( LogFile, "\" ) = 0 Then LogFile = fso.BuildPath( Home, LogFile ) 'logfile is plain filename, append script path
    If fso.FileExists( LogFile ) Then
        Set f = fso.GetFile( LogFile )
        If LogAppend Then
            If f.Size > MaxLog Then
                f.Copy fso.GetParentFolderName( LogFile ) & "\" & fso.GetBaseName( LogFile ) & ".BAK", True
                f.Delete True
            End If 'f.Size > MaxLog
        Else
            f.Delete True
        End If 'LogAppend
    End If 'fso.FileExists( LogFile )
    If err.Number <> 0 Then
        'can't use sub finish() - have no logfile at the moment...
        WScript.Echo err.Source & ": " & err.Number & " (" & err.Description & ")"
        WScript.Quit err.Number
    End If 'err.Number <> 0
End If 'LogFile <> ""

'initialize internet explorer when running under wscript
If WshHost = "WSCRIPT" And LogScreen Then InitIE

'initialize log file
Set f = fso.GetFile( WScript.ScriptFullName )
ScriptDate = f.DateLastModified
Call Writelog( "" )
Call Writelog( String( 65, "*" ) )
Call Writelog( String( 65, "*" ) )
Call Writelog( f.Path & " version " & ScriptVersion & " started." )
Call Writelog( "Scriptfile date " & ScriptDate & ", size " & FormatNumber( f.Size, 0, True, False, True  ) & " bytes." )
Call Writelog( "Running on machine " & ComputerName & " as user " & UserName & " (domain: " & DomainName & ")" )
If Args <> "" Then
    Call Writelog( "Arguments:" & Args )
Else
    Call Writelog( "Arguments: none" )
End If 'Args <> ""
If Logfile <> "" Then Call Writelog( "Logfile: " & Logfile )
Call Writelog( String( 65, "*" ) )
Call Writelog( "" )

'initialize registry hive and type dictionary
AddToDict "HKey", "HKCR", &H80000000
AddToDict "HKey", "HKCU", &H80000001
AddToDict "HKey", "HKLM", &H80000002
AddToDict "HKey", "HKU" , &H80000003
AddToDict "HKey", "HKCC", &H80000005
AddToDict "HKey", "HKDD", &H80000006 'Win95/98 only
'registry data types
AddToDict "HKey", "REG_NONE"                        ,  0
AddToDict "HKey", "REG_SZ"                          ,  1
AddToDict "HKey", "REG_EXPAND_SZ"                   ,  2
AddToDict "HKey", "REG_BINARY"                      ,  3
AddToDict "HKey", "REG_DWORD"                       ,  4
AddToDict "HKey", "REG_DWORD_BIG_ENDIAN"            ,  5
AddToDict "HKey", "REG_LINK"                        ,  6
AddToDict "HKey", "REG_MULTI_SZ"                    ,  7
AddToDict "HKey", "REG_RESOURCE_LIST"               ,  8
AddToDict "HKey", "REG_FULL_RESOURCE_DESCRIPTOR"    ,  9
AddToDict "HKey", "REG_RESOURCE_REQUIREMENTS_LIST"  , 10
AddToDict "HKey", "REG_QWORD"                       , 11

Mode = UCase( Mode )
If PolFile <> "" Then PolFile = fso.GetAbsolutePathName( PolFile )
If TxtFile <> "" Then TxtFile = fso.GetAbsolutePathName( TxtFile )

Select Case Mode
    Case "R"
        If Polfile = "" Then
            Writelog "No registry.pol file specified for input."
            Writelog "See " & Self & "/? for help."
            Finish( 2 )
        End If
        If Not fso.FileExists( PolFile ) Then
            Writelog "Input file """ & PolFile & """ doesn't exist."
            Writelog "See " & Self & " /? for help."
            Finish( 2 )
        End If
        If TxtFile <> "" And fso.FileExists( TxtFile ) Then DelFile TxtFile
        Writelog "Reading file " & PolFile
        Writelog "(Total size: " & FormatNumber( fso.GetFile( PolFile ).Size, 0, False, False, True ) & " bytes)"
        Writelog ""

        'read the registry.pol file
        Set PolStream = CreateObject( "ADODB.Stream" )              'Create Stream object
        PolStream.Type = adTypeBinary                               'Specify stream type - we want to get binary data.
        PolStream.Open                                              'Open the stream
        PolStream.LoadFromFile PolFile                              'Load the file data from disk To stream object
        PolData = ""
        Do While Not PolStream.EOS                                  'Open the stream and get binary data from the object
            PolData = PolData & ByteArray2Text( PolStream.Read )
        Loop
        PolStream.Close                                             'PolData now contains the registry.pol file in binary format

        PolData = Mid( PolData, 9 )                                 'skip header bytes (signature "PReg" and file version)
        t = ""
        For i = 1 To Len( PolData ) Step 2                          'strip zero bytes
            t = t & Mid( PolData, i, 1 )
        Next
        'the lenght of t always is (registry.pol-size - 8)/2
        Writelog "Policy data processed, size " & FormatNumber( Len( t ), 0, False, False, True ) & " bytes."

        'all policy entries are separatet by [braces], so let's
        'split data into keys, skip first "[" and last "]"
        PolData = Split( Mid( t, 2, Len( t ) - 2 ), "][", -1, vbTextCompare )

        Writelog "Enumerating policies (" & UBound( PolData ) + 1 & " keys)"
        For Each t In PolData
            l = ""      'this holds the string we build for output
            v = True    'this is false for action statements (**delKey...)
            'the common data format for policy entries is [key;value;type;size;data]
            k = Split( t, ";", 5, vbTextCompare )
            For i = 0 To UBound( k )    'process key-value-type-size-data
                'last byte is always zero except for data in k( 4 ), so strip it
                If i <> 4 Then k( i ) = StripLast( k( i ) )
            Next
            'now things are getting confusing...

            'let's start our output string with the registry key k( 0 )
            l = k( 0 )

            'then we append the registry value name k( 1 )
            If Left( k( 1 ), 2 ) = "**" Then v = False      'action statements (starting with "**")
            If Asc( k( 1 ) ) = 0 Then                       'Null means default value
                l = l & KeySep & "@"
            Else
                l = l & KeySep & k( 1 )
            End If
            l = l & ValueSep

            'let's tell the user what type of data we have in k( 2 )
            w = HKey.Item( Asc( k ( 2 ) ) ) 'we have to remember our data type when we format the data itself
            l = l & w

            Select Case w
                Case "REG_SZ"
                    y = StringToHex( k( 4 ) )   'convert to readable hex string
                    y = ReplaceHex( y, "0D0A", StringToHex( MultiSep ) )    'replace CrLf with /MultiSep
                    y = ReplaceHex( y, "00", StringToHex( NullChar ) )      'replace nul with /NullChar
                    y = HexToString( y )        'reconvert to ascii string
                Case "REG_EXPAND_SZ"
                    y = StringToHex( k( 4 ) )
                    y = ReplaceHex( y, "0D0A", StringToHex( MultiSep ) )
                    y = ReplaceHex( y, "00", StringToHex( NullChar ) )
                    y = HexToString( y )
                Case "REG_MULTI_SZ"
                    y = StringToHex( k( 4 ) )
                    y = ReplaceHex( y, "0D0A", StringToHex( MultiSep ) )
                    y = ReplaceHex( y, "00", StringToHex( NullChar ) )
                    y = HexToString( y )
                Case "REG_DWORD"
                    k( 4 ) = StringToHex( k( 4 ) )  'convert to readable hex string
                    k( 4 ) = ConvLowHigh( k( 4 ) )  'swap low and high bytes
                    k( 4 ) = HexToString( k( 4 ) )  'reconvert to binary data
                    y = StringToHex( k( 4 ) )       'create second string
                    y = LongHex( y )                'calculate 64 bit integer
                Case "REG_QWORD"
                    k( 4 ) = StringToHex( k( 4 ) )
                    k( 4 ) = ConvLowHigh( k( 4 ) )
                    k( 4 ) = HexToString( k( 4 ) )
                    y = StringToHex( k( 4 ) )
                    y = LongHex( y )
                Case Else   'unknown data type, uh?
                    y = StringToHex( k( 4 ) )   'let's at least convert it to something readable...
                    y = LongHex( y )
                End Select
            'y contains the readable form of our data, k( 4 ) is the binary data
            If NoHex Then
                l = l & TypeSep & y
            Else
                l = l & TypeSep & HexMarker & StringToHex( k( 4 ) ) & DataSep & "(" & y & ")"
            End If
            Writelog l
            If TxtFile <> "" Then RC = AppendFile( TxtFile, l & VbCrLf )
        Next
    Case "C"
        If TxtFile = "" Then
            Writelog "No registry.txt file specified for input."
            Writelog "See " & Self & " /? for help."
            Finish( 2 )
        End If
        If Not fso.FileExists( TxtFile ) Then
            Writelog "Input file """ & TxtFile & """ doesn't exist."
            Writelog "See " & Self & " /? for help."
            Finish( 2 )
        End If
        If Polfile = "" Then
            Writelog "No registry.pol file specified for output."
            Writelog "See " & Self & "/? for help."
            Finish( 2 )
        End If
        If fso.FileExists( PolFile ) Then DelFile PolFile
        Set TxtStream = fso.OpenTextFile( TxtFile )
        Do While Not TxtStream.AtEndOfStream
            TxtData = TxtStream.ReadLine
            Writelog TxtData
            'creating registry.pol seems much easier - but look at ConvertTxtData() and get crazy.
            PolData = PolData & ConvertTxtData( TxtData )
        Loop
        PolData = PolHeader & PolData
        WriteFile PolFile, PolData
    Case Else
        Writelog "Invalid mode """ & Mode & """"
        Writelog ""
        Writelog "See " & Self & " /? for help."
        Finish( 87 )
End Select

Call Finish( 0 )

'converts a byte array (registry.pol) into a string with ADODB.Recordset
Function ByteArray2Text( ByVal ByteArray )
    Dim oRS
    Const adLongVarChar = 201
    Set oRS = CreateObject( "ADODB.Recordset" )
    oRS.Fields.Append "temp", adLongVarChar, LenB( ByteArray )
    oRS.Open
    oRS.AddNew
    oRS( "temp" ).AppendChunk ByteArray
    oRS.Update
    ByteArray2Text = oRS( "temp" )
    oRS.Close
    Set oRS = Nothing
End Function

'converts a string to a hex string
'"c:\" -> "633A5C"
Function StringToHex( ByVal StringData )
    Dim HexData
    Do While StringData <> ""
        HexData = HexData & Right( "00" & Hex( Asc( Left( StringData, 1 ) ) ), 2 )
        StringData = Mid( StringData, 2 )
    Loop
    StringToHex = HexData
End Function

'converts a hex string to ascii
'"0x633A5C" -> "c:\"
Function HexToString( ByVal HexData )
    Dim StringData
    Do While HexData <> ""
        StringData = StringData & Chr( "&H" & Left( HexData, 2 ) )
        HexData = Mid( HexData, 3 )
    Loop
    HexToString = StringData
End Function

'converts a string representing a bitmask to its hex string
'"0b00011" -> "0x3"
Function BinToHex( ByVal BinData )
    Dim HexData, MyMulti, MyCount
    MyMulti = 1
    HexData = 0
    For MyCount = Len( BinData ) To 1 Step -1
        Writelog MyCount
        If Mid( BinData, MyCount ) = 1 Then HexData = HexData + MyMulti
        MyMulti = MyMulti * 2
    Next
    BinToHex = HexMarker & Hex( HexData )
End Function

'creates the string in a policy file from the given text string
Function ConvertTxtData( ByVal TxtData )
    'TxtData contains key:value=type:data (ascii/decimal)
    Dim RegKey, RegValue, RegType, RegSize, RegData, RegString

    'split to get RegKey
    t = Split( TxtData, KeySep, 2 ) 'KeySep is defined in header
    RegKey = t( 0 )
    TxtData = t( 1 )

    'split again to get value name
    t = Split( TxtData, ValueSep, 2 ) 'ValueSep is defined in header
    RegValue = t( 0 )
    If RegValue = "@" Then RegValue = "" 'default entry

    'next split returns value type and value data
    u = Split( t( 1 ), TypeSep, 2 ) 'TypeSep is defined in header
    RegType = u( 0 )
    If UBound( u ) > 0 Then 'check if we have data
        RegData = u( 1 )    'ok, value present
    Else
        RegData = ""        'no value present
    End If

    If UCase( RegData ) = UCase( SameAsValue ) Then
        RegData = RegValue & NullChar 'if "SameAsValue" abbrev is used, a nul byte has to be padded
    End If
    If RegType = "REG_DWORD" Then
        If UCase( Left( RegData, 2 ) ) <> UCase( BinMarker ) And UCase( Left( RegData, 2 ) ) <> UCase( HexMarker ) Then
            'data present as decimal number
            'convert decimal number to binary (each character represents a byte)
            RegData = NumToChar( RegData )
            'if odd number of chars: add leading nul byte
            If Len( RegData ) = 1 Or Len( RegData ) = 3 Then RegData = Chr( 0 ) & RegData
            'hex numbers in pol files are reverse order...
            RegData = Reverse( RegData )
        End If
        If UCase( Left( RegData, 2 ) ) = UCase( BinMarker ) Then    'data as binary
            'data present as binary mask
            'strip data separator, retain data only
            v = Split( RegData, DataSep, 2 )
            'strip leading "0b" or whatever the marker for binary data may be.
            RegData = Mid( v( 0 ), Len( BinMarker ) + 1 )
            'convert binary string to hex
            '"0b00011" -> "0x3"
            RegData = BinToHex( RegData )
        End If
    End If
    If UCase( Left( RegData, 2 ) ) = UCase( HexMarker ) Then
        'data as hex number, may be used with all types, not only REG_DWORD
        'strip trailing ascii/decimal data, if present
        v = Split( RegData, DataSep, 2 )
        'strip leading "0x" (aka HexMarker)
        RegData = Mid( v ( 0 ), Len( HexMarker ) + 1 )
        'swap low and high bytes
        If UCase( RegType ) = "REG_DWORD" Then RegData = ConvLowHigh( RegData )
        'convert hex string to ascii string
        '"0x633A5C" -> "c:\"
        RegData = HexToString( RegData )
    End If
    Select Case UCase( RegType )
        Case "REG_DWORD"
            'nothing to do - DWords are already fully converted
        Case "REG_QWORD"
            'we do NOT process QWords...
            ConvertTxtData = ""
            Exit Function
        Case Else
            'replace readable <00> and <CRLF> notation with their binary characters
            RegData = StringToHex( RegData )
            RegData = ReplaceHex( RegData, StringToHex( NullChar ), "00" )
            RegData = ReplaceHex( RegData, StringToHex( MultiSep ), "0D0A" )
            RegData = HexToString( Regdata )
    End Select
    RegType = NumToChar( HKey.Item( RegType ) ) 'reg hive as hex value, converted to binary notation
    RegSize = NumToChar( Len( RegData ) * 2 )   'reg data length in decimal, converted to binary notation
    ConvertTxtData = PadZeros( "[" & RegKey & Chr( 0 ) & ";" & RegValue & Chr( 0 ) & ";" & RegType & Chr( 0 ) & ";" ) 'unicode... so pad nul bytes
    ConvertTxtData = ConvertTxtData & RegSize   'append size of registry data
    If Len( RegSize ) = 1 Then ConvertTxtData = ConvertTxtData & Chr( 0 )   'pad nul byte for odd length of data size byte
    ConvertTxtData = ConvertTxtData & PadZeros( Chr( 0 ) & ";" & RegData & "]" )    'append registry data, padded with nul bytes.
End Function

'convert given number to ASCII chars, eg. "260" results in the ascii letters for 256 and 4 (not printable, of course)
Function NumToChar( ByVal Number )
    If Number > 255 Then
        NumToChar = NumToChar( Number \ 256 )
        Number = Number - ( Number \ 256 ) * 256
    End If
    NumToChar = Chr( Number ) & NumToChar
End Function

'policy files deal with qwords, vbscript can't easily handle them...
'takes a given hex number (FF e.g.) and returns a 64 bit number
'the &H-function is limited to 32 bit integer, LongHex can deal with 64 bit
Function LongHex( ByVal HexNum )
    Dim MyMult, MyCount
    MyMult = CDbl( 1 )
    LongHex = CDbl( 0 )
    For MyCount = Len( HexNum ) To 1 step -1
        Execute "LongHex = LongHex + &H" &  Mid( HexNum, MyCount, 1 ) & "* MyMult"
        MyMult = MyMult * 16
    Next
End Function

'strip the last character of given string if strlen > 1
Function StripLast( ByVal Text )
    StripLast = Text
    If Len( Text ) > 1 Then StripLast = Left( Text, Len( Text ) - 1 )
End Function

'replace hex numbers in hex strings (0xFF)
'"633A5C10,3A5C,FF" -> "63FF10"
Function ReplaceHex( ByVal Text, OldPart, NewPart ) '
    Dim MyCount, MyStep, MyPart
    MyStep = Len( OldPart )
    ReplaceHex = ""
    For MyCount = 1 To Len( Text ) Step 2
        MyPart = Mid( Text, MyCount, MyStep )
        If MyPart = OldPart Then
            ReplaceHex = ReplaceHex & NewPart
            MyCount = MyCount + MyStep - 2
        Else
            ReplaceHex = ReplaceHex & Mid( Text, MyCount, 2 )
        End If
    Next
End Function

'add nul byte after every char - "unicode" for the poor ones ;-)
Function PadZeros( ByVal Text )
    Dim MyCount
    PadZeros = ""
    For MyCount = 1 To Len( Text )
        PadZeros = PadZeros & Mid( Text, MyCount, 1 ) & Chr( 0 )
    Next
End Function

'swap low and high "byte" of 4 character hex string - "little/big endian"
'"633AF94E" -> "3A634EF9"
Function ConvLowHigh( ByVal Text )
    Dim MyCount
    ConvLowHigh = ""
    For MyCount = 1 To Len( Text ) Step 4
        ConvLowHigh = ConvLowHigh & Mid( Text, MyCount + 2, 2 ) & Mid( Text, Mycount, 2 )
    Next
End Function

'return reversed string (vbscript has no builtin function for that...)
Function Reverse( ByVal Text )
    Do While Text <> ""
        Reverse = Reverse & Right( Text, 1 )
        Text = Mid( Text, 1, Len( Text ) - 1 )
    Loop
End Function

'catch os errors, quit script if requested
Sub CheckOSError( ByVal Message, ByVal QuitOnError )
    If err.Number <> 0 Then
        Call Writelog( "      Error : " & Message )
        Call Writelog( "      Source: " & err.Source )
        Call Writelog( "      Number: 0x" & Right( "00000000" & Hex( err.Number ), 8 ) & " (" & err.Number & ")" )
        Call Writelog( "      Descr.: " & err.Description )
        If QuitOnError Then Call Finish( err.Number ) 'return error
        err.Clear
    End If 'err.Number <> 0
End Sub

'clean up before terminating
Sub Finish( ScriptRC )
    ScriptRC = CStr( ScriptRC )
    Call Writelog( "" )
    Call Writelog( String( 65, "*" ) )
    Call Writelog( Self & " finished, RC=" & ScriptRC )
    Call Writelog( String( 65, "*" ) )
    Call Writelog( String( 65, "*" ) )
    Call Writelog( "" )
    If WshHost = "WSCRIPT" And ScriptRC <> 99 And LogScreen Then
        With oIE
            .Document.WriteLn( "</code>" )
            .Document.WriteLn( "<h3>" & Self & " finished.</h3>" )
            .Document.WriteLn( "Close window to exit.<br>" )
            .Document.WriteLn( "</body>" )
            .Document.WriteLn( "</html>" )
            .Document.Body.ScrollTop = .Document.Body.ScrollHeight  'scroll to bottom
            .Document.Close
        End With 'oIE
    End If 'WshHost = "WScript" And ScriptRC <> 99
    WScript.Quit( ScriptRC )
End Sub

'log a message to screen/file
Sub WriteLog( ByVal LogMessage )
    Dim Prefix, File
    If WshHost = "CSCRIPT" And LogScreen Then Call WScript.Echo( CStr( Time ) & " " & LogMessage ) 'log to console
    If WshHost = "WSCRIPT" And LogScreen And ScriptRC <> 99 Then Call WriteIE( LogMessage )        'log to IE window
    If LogFile <> "" Then                                                                          'log to File
        Set File = fso.OpenTextFile( LogFile, 8, True )
        File.WriteLine( "[" & CStr( Now ) & "] " & LogMessage )
        File.Close
        Set File = Nothing
    End If 'LogFile <> ""
End Sub

Sub WriteIE( ByVal IeMessage )
    Dim CurrChar, NewMessage, my_i
    Do 'While oIE.Busy
        WScript.Sleep( 10 )
    Loop While oIE.Busy                         'be sure IE is ready for interaction
    NewMessage = ""
    For my_i = 1 To Len( IeMessage )            'replace spaces with nbsp's for formatting in ie
        CurrChar = Mid( IeMessage, my_i, 1 )
        If CurrChar = " " Then
            NewMessage = NewMessage & "&nbsp;"
        Else
            NewMessage = NewMessage & CurrChar
        End If
    Next
    With oIE
        .Document.WriteLn( CStr( Time ) & "&nbsp;" & NewMessage & "<br>" )  'log to IE window
        .Document.Body.ScrollTop = .Document.Body.ScrollHeight              'scroll to bottom
    End With 'oIE
End Sub

'initialize ie window for log output when using wscript
Sub InitIE()
    err.Clear
    Set oIE = WScript.CreateObject( "InternetExplorer.Application", "IEWindow_" )
    Call CheckOsError( "Creating oIE application object", True )
    With oIE
        .Navigate( "about:blank" )
        .Menubar = False
        .Toolbar = False
        .Statusbar = False
        Do While .Busy
            WScript.Sleep( 100 )
        Loop 'While .Busy
        .Document.Open
        .Document.WriteLn( "<html><head><title>" & Self & "</title></head>" )
        .Document.WriteLn( "<body><font face='courier new'>" )
        .Document.WriteLn( "<h3>" & Self & " initialized.</h3>" )
        .Document.WriteLn( "Close window to terminate script abnormally.<br><br>" )
        .Document.WriteLn( "<code>" )
        .Visible = 1
    End With 'oIE
End Sub

'catch user closing ie log output window
Sub IEWindow_OnQuit()
    If MsgBox( "Do you really want to abort the current script" & VbCrLf & _
                WScript.ScriptFullName & "?", _
                VbYesNo + VbExclamation + VbDefaultButton2, _
                Self ) = VbYes _
    Then
        oIE.Visible = 0
        Call MsgBox( WScript.ScriptFullName & VbCrLf & _
                "Script aborted by user!", VbOkOnly + VbCritical, _
                Self )
        Call Finish( 99 )   '99 means "user abort" - can't cleanup IE window when already closed
    Else
        Set oIE = Nothing
        Call InitIE
    End If 'MsgBox( "Do you really [...]
End Sub

'write a string to a file
Function WriteFile( FileName, Contents )
    FileName = oWSH.ExpandEnvironmentStrings( FileName )
    Dim FileStream
    Set FileStream = fso.OpenTextFile( FileName, 2, True )
    err.Clear
    WriteFile = FileStream.Write( Contents )
    Call CheckOsError( "Writing Outfile " & FileName, True )
    FileStream.Close
End Function

'append a string to a file
Function AppendFile( FileName, Contents )
    FileName = oWSH.ExpandEnvironmentStrings( FileName )
    Dim FileStream
    Set FileStream = fso.OpenTextFile( FileName, 8, True )
    err.Clear
    AppendFile = FileStream.Write( Contents )
    Call CheckOsError( "Appending Outfile " & FileName, False )
    FileStream.Close
End Function

Sub AddToDict( DictName, DictVar, DictVal ) 'initialise dictionary objects, create name->value and value->name pairs
    Dim my_i
    If IsNumeric( DictVar ) Then
        my_i = DictVal
        DictVal = DictVar
        DictVar = my_i
    End If
    Call Execute( "If Not " & DictName & ".Exists( """ & DictVar & """ ) Then " & DictName & ".Add """ & DictVar & """, " & DictVal )
    Call Execute( "If Not " & DictName & ".Exists( " & DictVal & " ) Then " & DictName & ".Add " & DictVal & ", """ & DictVar & """" )
End Sub
