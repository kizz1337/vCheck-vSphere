# Recuperation des jobs xml
$xml_cvc = Get-Item .\jobs\*.xml

$Runingpath = "D:\vCheck-vSphere\jobs"
# Add remote destination, set $false to disable
$remotepath = "\\RemoteServer\vCheck"
$Outputpath = "D:\vCheck-vSphere\vCheck"

# Use the following item to define if an email report should be sent once completed
$SendEmail = $true
# Please Specify the SMTP server address (and optional port) [servername(:port)]
$SMTPSRV = "mysmtpserver.mydomain.local"
# Would you like to use SSL to send email?
$EmailSSL = $false
# Please specify the email address who will send the vCheck report
$EmailFrom = "me@mydomain.local"
# Please specify the email address(es) who will receive the vCheck report (separate multiple addresses with comma)
$EmailTo = "me@mydomain.local"
# Please specify the email address(es) who will be CCd to receive the vCheck report (separate multiple addresses with comma)
$EmailCc = ""
# Please specify an email subject
$EmailSubject = "vCheck Report"
# If you would prefer the HTML file as an attachment then enable the following:
$SendAttachment = $false


if ((Test-Path $Outputpath) -ne $true) {
	write-host "Creation du output"
	New-Item -ItemType directory -Path $Outputpath
}

$Array = @()
$CVC = "" | select Name,Done
foreach ($VIServer in $xml_cvc.Name) {
	$CVC.Name = $VIServer.Substring(0,$VIServer.Length-4)
	write-host "Starting job on $VIServer"
	write-host ""lancement de la commande : D:\vCheck-vSphere\vCheck.ps1 -Outputpath $Outputpath -job $Runingpath\$VIServer""
	start-job -ScriptBlock { D:\vCheck-vSphere\vCheck.ps1 -Outputpath $args[0] -job $args[1] } -ArgumentList $Outputpath,$Runingpath\$VIServer -Name $CVC.Name
	
	$d = New-Object PSObject
	$d | Add-Member -Name Name -MemberType NoteProperty -Value $CVC.Name
	$d | Add-Member -Name Done -MemberType NoteProperty -Value $false
	$Array+=$d
}
write-host $Array.count" Job are running !"

Write-host "Wait for all job done !"
get-job | ?{$_.Name -In $Array.Name} | Wait-Job

# All job done, So We can remove them !
get-job | ?{$_.Name -In $Array.Name -And $_.State -eq "Completed"} | Remove-Job

if ($remotepath) {
	if ((Test-Path $Outputpath\Archives) -eq $true) {
		write-host "Déplacement des rapports"
		Move-Item $Outputpath $remotepath -force
	}
}

if ($SendEmail) {
	Write-host "Generating E-mail"
   $msg = New-Object System.Net.Mail.MailMessage ($EmailFrom,$EmailTo)
   # If CC address specified, add
   If ($EmailCc -ne "") {
      $msg.CC.Add($EmailCc)
   }
   $msg.subject = $EmailSubject
   
   # if send attachment, just send plaintext email with HTML report attached
   If ($SendAttachment) {
      $msg.Body = $lang.emailAtch
      $attachment = new-object System.Net.Mail.Attachment $Filename
      $msg.Attachments.Add($attachment)
   }
   # Otherwise send the HTML email
   else {
      $msg.IsBodyHtml = $true;
$MyReport = "
			Bonjour,<br>
			Vous recevez-ce message car vous êtes inscrit au rapport : Etat des lieux VMWare<br>
			Les rapports ont été générer et sont disponible a l'adresse suivante : http://RemoteServer/vCheck/"
      $html = [System.Net.Mail.AlternateView]::CreateAlternateViewFromString($MyReport,$null,'text/html')
      $msg.AlternateViews.Add($html)
   }
   # Send the email
   $smtpClient = New-Object System.Net.Mail.SmtpClient
   
   # Find the VI Server and port from the global settings file
   $smtpClient.Host = ($SMTPSRV -Split ":")[0]
   if (($server -split ":")[1]) {
      $smtpClient.Port = ($server -split ":")[1]
   }
   
   if ($EmailSSL -eq $true) {
      $smtpClient.EnableSsl = $true
   }
   $smtpClient.UseDefaultCredentials = $true;
   $smtpClient.Send($msg)
   If ($SendAttachment) { $attachment.Dispose() }
   $msg.Dispose()
}