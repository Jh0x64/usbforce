' USBForce - Mente Bin�ria - Fernando Merc�s
' Data de in�cio do c�digo: 1/2/2010 01:32
' �ltima altera��o: 31/1/2010 20:38

' This program is free software: you can redistribute it and/or modify
' it under the terms of the GNU General Public License as published by
' the Free Software Foundation, either version 3 of the License, or
' (at your option) any later version.

' This program is distributed in the hope that it will be useful,
' but WITHOUT ANY WARRANTY; without even the implied warranty of
' MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
' GNU General Public License for more details.

' You should have received a copy of the GNU General Public License
' along with this program.  If not, see <http://www.gnu.org/licenses/>.

'Vers�o do USBForce
Versao = "1.2"

' Checa por atualiza��es
'On Error Resume Next
'Set objShell = CreateObject("WScript.Shell") 
'objShell.Run "Updater.exe /s"

' Defini��o de vari�veis e constantes
Enabled = False
Const HKLM = &H80000002
Const LEITURA = 1
Const ESCRITA = 2
strComputer = "."
Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & _
    strComputer & "\root\default:StdRegProv")

' Fun��o que checa se a prote��o est� ativa
Function checaProtecao()
	
	Enabled = False
	
	' Verifica o valor "Enabled"
	Chave = "SOFTWARE\MenteBinaria\USBForce"
	Valor = "Enabled"
	objReg.GetDWORDValue HKLM, Chave, Valor, dwValor
	
	If dwValor <> "" Then
		If dwValor = 1 Then
			Enabled = True
		End If
	End If
	
	checaProtecao = Enabled
	
End Function

' Procedimento para abrir um pasta com o Windows Explorer
Sub abrePasta(path)

	Set objShell = CreateObject("WScript.Shell") 
	objShell.Run "C:\WINDOWS\explorer.exe " + path

End Sub

' Procedimento que escreve no log
Sub escreveLog(tipo, desc)

	' Pega a data e hora atual no formato "dd/mm/yyyy HH:MM"
	Agora = FormatDateTime(Date, 2) & " " & Time
	
	Set objFSO = CreateObject("Scripting.FileSystemObject")
	Set objShell = CreateObject("Wscript.Shell")

	' Arquivo de log no diret�rio do programa
	logFile = "USBForce_Log.txt"
	
		' Se o arquivo de log n�o existir, � criado
	If Not objFSO.FileExists(logFile) Then
		
		objFSO.CreateTextFile(logFile)
		Set objLog = objFSO.OpenTextFile(logFile, ESCRITA)
		objLog.Write Agora & vbTab & "1" & vbTab & "Criado novo arquivo de log."
		objLog.Close
		
	End If
	
	' Adiciona uma entrada no in�cio do arquivo de log
	Set objLogW = objFSO.OpenTextFile(logFile, LEITURA)
	strContents = objLogW.ReadAll
	objLogW.Close
	Set objLogW = objFSO.OpenTextFile(logFile, ESCRITA)
	objLogW.WriteLine objLogW.Write(Agora & vbTab & tipo & vbTab & desc)
	objLogW.Write strContents
	objLogW.Close
	
End Sub

' Fun��o que recebe o tamanho em bytes e retorna-o da melhor maneira
Function ajustaTamanho(tam)

	If tam < 1024 Then
		ajustaTamanho = tam & " Bytes"
	ElseIf tam < 1048576 Then
		ajustaTamanho = Round(tam / 2^10, 2) & " KB"
	ElseIf tam < 1073741824 Then
		ajustaTamanho = Round(tam / 2^20, 2) & " MB"
	ElseIf tam < 1099511627776 Then
		ajustaTamanho = Round(tam / 2^30, 2) & " GB"
	End if

End Function

If checaProtecao() Then
	
	'Se estiver habilitado
	Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")

	Set colDisks = objWMIService.ExecQuery _
    ("Select * from Win32_LogicalDisk")
    
    Set objFSO = CreateObject("Scripting.FileSystemObject")
    
    discos = 0
    
	' Varre a lista de unidades dispon�veis
	For Each objDisk in colDisks
	
	    ' Se for uma unidade remov�vel com exce��o do disquete
	    If objDisk.DriveType = 2 And objDisk.Name <> "A:" And objDisk.Name <> "B:" Then
	    	
	    	discos = discos + 1
	    	
	    	inf = objDisk.Name + "\autorun.inf"
	    
	    	' Se n�o existir autorun.inf, abre no Expolrer e sai
	    	If Not objFSO.FileExists(inf) Then

	    		abrePasta(objDisk.Name)

			' Se existir autorun.inf, procura a linha open e sugere apagar os arquivos
	    	Else

	    		Set objTxt = objFSO.OpenTextFile(inf, LEITURA)
	    		
	    		Do Until objTxt.AtEndOfStream
	    		
	    			linha = objTxt.ReadLine()
	    			
	    			' Procura open=
					OpenPos = InStr(1, linha, "open=", vbTextCompare)
					
					'Procura shell\command
					CommandPos = InStr(1, linha, "\command=", vbTextCompare)
					
	    			If OpenPos > 0 Or CommandPos > 0 Then
	    				exe = objDisk.Name + "\" + _
	    					  Mid(linha,InStr(1, linha, "=", vbTextCompare)+1)
	    			End If

	    		Loop
	    		
	    		If Not objFSO.FileExists(exe) Then
	    				exe = ""
	    		End If
	    		
	    		' Fecha o autorun.inf, aberto anteriormente, para poder apag�-lo no futuro
	    		objTxt.Close()
	    		
				' Escreve no log
				escreveLog "2", "Ind�cios de v�rus detectados na m�dia " & objDisk.Name & " (" _
	    				& objDisk.VolumeName & ")."
	    		
	    		Set objFile = objFSO.GetFile(inf)
	    		
	    		texto = "Ind�cios de v�rus detectados na m�dia " & objDisk.Name & " (" _
	    				& objDisk.VolumeName & "). Voc� deve apagar os arquivos:" + vbCrLf + vbCrLf _
	    				& inf & " (" & ajustaTamanho(objFile.Size) & "), " & "criado em " & objFile.DateCreated & vbCrLf
	    		
	    		' Se o EXE existir, tem seus detalhes exibidos
	    		If exe <> "" Then
	    		
		    		Set objFile = objFSO.GetFile(exe)
		    		
		    		texto = texto _
		    				& exe & " (" & ajustaTamanho(objFile.Size) & "), " & "criado em " & objFile.DateCreated & vbCrLf
	    				
	    		End If
	    		
	    		texto = texto & vbCrLf & vbCrLf & "Deseja que o USBForce os apague pra voc�?"
	    		
	    		r = MsgBox(texto, vbYesNo + vbExclamation, "USBForce " + Versao)
	    				
	    	    If r = 6 Then
	    	    	
	    	    	' Tratamento de erroOn Error Resume Next

	    	    	On Error Resume Next
	    	    	Err.Clear()
					
					' Tenta apagar o .inf e o .exe indicado na linha open=	    	    	    	    	
	    	    	If objFSO.FileExists(inf) Then
	    				objFSO.DeleteFile inf, True
	    			End If
					
	    			If objFSO.FileExists(exe) Then
	    				objFSO.DeleteFile exe, True
	    			End If
	    			
	    			' Caso n�o consiga apagar um deles, sugere que a dele��o manual seja feita
	    			If Err.Number <> 0 Then
	    				
	    				escreveLog "9", "N�o foi poss�vel apagar um ou mais arquivos na m�dia " _
	    				& objDisk.Name & " (" & objDisk.VolumeName & ")."

	    				MsgBox "N�o foi poss�vel apagar um ou mais arquivos na m�dia " + objDisk.Name + " (" _
	    				+ objDisk.VolumeName + "). Voc� deve apagar MANUALMENTE os arquivos:" + vbCrLf + vbCrLf _
	    				+ inf + vbCrLf + exe, vbOKOnly + vbCritical, "USBForce " + Versao
	    				
	    			Else

	    				escreveLog "1", "Arquivos apagados com sucesso da m�dia "_
	    				& objDisk.Name & " (" & objDisk.VolumeName & ")."
	    				
	    				MsgBox "Arquivos apagados. O USBForce mostrar� agora o conte�do da m�dia."_
	    				, vbOKOnly + vbInformation, "USBForce " +  Versao
	    				abrePasta(objDisk.Name)
	    				
	    			End If
	    			
	    	    Else

	    	    	WScript.Quit(1)
    	
	    	    End If
	    		
	    	End If
	      	
	    End If
	
	Next	
	
Else
	' Se a prote��o estiver desabilitada...
	
	' Objeto para pegar o nome da m�quina
	Set objRede = CreateObject("WScript.Network")
	
	' Cria a chave MenteBinaria\USBForce
	Chave = "SOFTWARE\MenteBinaria\USBForce"
	Valor = "Enabled"
	objReg.CreateKey HKLM, Chave
	
	' Cria o valor Enabled ativo
	objReg.SetDWORDValue HKLM, Chave, Valor, 1
	
	' Desabilita o autorun para todas as unidades
	Chave = "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
	Valor = "NoDriveTypeAutoRun"
	objReg.CreateKey HKLM, Chave
	objReg.SetDWORDValue HKLM, Chave, Valor, &Hdf ' Desabilita o autorun para todas as m�dias, exceto CDs/DVDs
	
	' Valores poss�veis s�o:
'	0x1	 drives desconhecidos
'	0x4	 drives remov�ves
'	0x8	 drives fixos
'	0x10 drives de rede
'	0x20 drives cd CD/DVD
'	0x40 RAM drives
'	0x80 drives de tipo desconhecido
'	0xFF todos os drives
	
	' Desabilita execu��o do autorun.inf
	Chave = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\IniFileMapping\Autorun.inf"
	objReg.CreateKey HKLM, Chave
	objReg.SetStringValue HKLM, Chave, "", "@SYS:DoesNotExist" + objRede.ComputerName
	
	If (checaProtecao) Then
	
		escreveLog "1", "Prote��o habilitada pelo usu�rio " & objRede.UserName & "."
	
		MsgBox "USBForce habilitado. Fa�a logon novamente ou reinicie o PC.", vbInformation, "USBForce " + Versao
	
	Else
	
		MsgBox "� necess�rio executar o USBForce como administrador na primeira vez."_
		, vbExclamation, "USBForce " + Versao
	
	End If
	
	WScript.Quit

End If

If discos = 0 Then
	MsgBox "Nenhuma m�dia encontrada. Verifique se a m�dia foi corretamente conectada na porta USB."_
	, vbExclamation, "USBForce " + Versao
End If