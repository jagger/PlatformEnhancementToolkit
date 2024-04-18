###########
#region ### global:Connect-PlatformInstance # Connects the user to a Platform Instance. Derived from Centrify.Platform.PowerShell.
###########
function global:Connect-PlatformInstance
{
	<#
	.SYNOPSIS
    This cmdlet connects you to a Platform Instance.

    .DESCRIPTION
    This cmdlet will connect you to a Platform Instance. Information about your connection information will
    be stored in global variables that will only exist for this PowerShell session.

    .INPUTS
    None.

    .OUTPUTS
    This cmdlet only outputs some information to the console window once connected. The cmdlet will store
    all relevant connection information in global variables that exist for this session only.

    .EXAMPLE
    C:\PS> Connect-PlatformInstance -Url mytenant.delinea.app -User myuser@domain.com
    This cmdlet will attempt to connect to mytenant.delinea.app with the user myuser@domain.com. You
    will be prompted for password and MFA challenges relevant for the user myuser@domain.com.

    .EXAMPLE
    C:\PS> Connect-PlatformInstance -Url mytenant.delinea.app -Client MyApp -Scope MyScope -Secret XXXXXXX
    This cmdlet will attempt to connect to mytenant.delinea.app with a OAUTH2 user defined in the Secret.
    This will not prompt for a password (non-interactive) as that is encrypted into the Secret parameter.

    .EXAMPLE
    C:\PS> Connect-PlatformInstance -EncodeSecret
    This cmdlet will attempt to encode a Confidental Client secret after being prompted for a username and password.
	#>
    [CmdletBinding(DefaultParameterSetName="All")]
	param
	(
		[Parameter(Mandatory = $false, Position = 0, HelpMessage = "Specify the URL to use for the connection (e.g. oceanlab.my.centrify.com).")]
		[System.String]$Url,
		
		[Parameter(Mandatory = $true, ParameterSetName = "Interactive", HelpMessage = "Specify the User login to use for the connection (e.g. CloudAdmin@oceanlab.my.centrify.com).")]
		[System.String]$User,

		[Parameter(Mandatory = $true, ParameterSetName = "OAuth2", HelpMessage = "Specify the OAuth2 Client ID to use to obtain a Bearer Token.")]
        [System.String]$Client,

		[Parameter(Mandatory = $true, ParameterSetName = "OAuth2", HelpMessage = "Specify the OAuth2 Scope Name to claim a Bearer Token for.")]
        [System.String]$Scope,

		[Parameter(Mandatory = $true, ParameterSetName = "OAuth2", HelpMessage = "Specify the OAuth2 Secret to use for the ClientID.")]
        [System.String]$Secret,

        [Parameter(Mandatory = $false, ParameterSetName = "Base64", HelpMessage = "Encode Base64 Secret to use for OAuth2.")]
        [Switch]$EncodeSecret
	)
	
	# Debug preference
	if ($PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent)
	{
		# Debug continue without waiting for confirmation
		$DebugPreference = "Continue"
	}
	else 
	{
		# Debug message are turned off
		$DebugPreference = "SilentlyContinue"
	}
	
	try
	{	
		# Set Security Protocol for RestAPI (must use TLS 1.2)
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Delete any existing connexion cache
        $Global:PlatformConnection = [Void]$null

        if ($EncodeSecret.IsPresent)
        {
             # Get Confidential Client name and password
             $Client = Read-Host "Confidential Client name"
             $SecureString = Read-Host "Password" -AsSecureString
             $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString))
             # Return Base64 encoded secret
             $AuthenticationString = ("{0}:{1}" -f $Client, $Password)
             return ("Secret: {0}" -f [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($AuthenticationString)))
        }

		if (-not [System.String]::IsNullOrEmpty($Client))
        {

			<# currently not working yet
            # Check if URL provided has "https://" in front, if so, remove it.
            if ($Url.ToLower().Substring(0,8) -eq "https://")
            {
                $Url = $Url.Substring(8)
            }
            
            # Get Bearer Token from OAuth2 Client App
			$BearerToken = Get-PlatformBearerToken -Url $Url -Client $Client -Secret $Secret -Scope $Scope

            # Validate Bearer Token and obtain Session details
            $Uri = ("https://{0}/Security/Whoami" -f $Url)
			$ContentType = "application/json" 
			$Header = @{ "X-CENTRIFY-NATIVE-CLIENT" = "1"; "Authorization" = ("Bearer {0}" -f $BearerToken) }
			Write-Debug ("Connecting to Delinea Platform (https://{0}) using Bearer Token" -f $Url)
			
			# Debug informations
			Write-Debug ("Uri= {0}" -f $Uri)
			Write-Debug ("BearerToken={0}" -f $BearerToken)
			
			# Format Json query
			$Json = @{} | ConvertTo-Json
			
			# Connect using Certificate
			$WebResponse = Invoke-WebRequest -UseBasicParsing -Method Post -SessionVariable PlatformSession -Uri $Uri -Body $Json -ContentType $ContentType -Headers $Header
            $WebResponseResult = $WebResponse.Content | ConvertFrom-Json
            if ($WebResponseResult.Success)
		    {
				# Get Connection details
				$Connection = $WebResponseResult.Result
				
				# Force URL into PodFqdn to retain URL when performing MachineCertificate authentication
				$Connection | Add-Member -MemberType NoteProperty -Name CustomerId -Value $Connection.InstanceId
				$Connection | Add-Member -MemberType NoteProperty -Name PodFqdn -Value $Url
				
				# Add session to the Connection
				$Connection | Add-Member -MemberType NoteProperty -Name Session -Value $PlatformSession

				# Set Connection as global
				$Global:PlatformConnection = $Connection

                # setting the splat
                $global:PlatformSessionInformation = @{ Headers = $PlatformConnection.Session.Headers }

                # if the $PlatformConnections variable does not contain this Connection, add it
                if (-Not ($PlatformConnections | Where-Object {$_.PodFqdn -eq $Connection.PodFqdn}))
                {
                    # add a new PlatformConnection object and add it to our $PlatformConnectionsList
                    $obj = New-Object -ArgumentList ($Connection.PodFqdn, $Connection, $global:PlatformSessionInformation)
					$global:PlatformConnections.Add($obj) | Out-Null
                }
				
				# Return information values to confirm connection success
				return ($Connection | Select-Object -Property CustomerId, User, PodFqdn | Format-List)
            }
            else
            {
                Throw "Invalid Bearer Token."
            }
			#>
			Write-Host ("Direct Bearer token login not working at this time. Try a local user instead.")
			return
        }	
        else
		{
			# Check if URL provided has "https://" in front, if so, remove it.
            if ($Url.ToLower().Substring(0,8) -eq "https://")
            {
                $Url = $Url.Substring(8)
            }
            # Setup variable for interactive connection using MFA
			$Uri = ("https://{0}/identity/Security/StartAuthentication" -f $Url)
			$ContentType = "application/json" 
			$Header = @{ "X-CENTRIFY-NATIVE-CLIENT" = "true" }
			Write-Host ("Connecting to Delinea Platform (https://{0}) as {1}`n" -f $Url, $User)
			
			# Debug informations
			Write-Debug ("Uri= {0}" -f $Uri)
			Write-Debug ("Login= {0}" -f $UserName)
			
			# Format Json query
			$Auth = @{}
			$Auth.InstanceId = $Url.Split('.')[0]
			$Auth.User = $User
            $Auth.Version = "1.0"
			$Json = $Auth | ConvertTo-Json
			
			# Initiate connection
			$InitialResponse = Invoke-WebRequest -UseBasicParsing -Method Post -SessionVariable PlatformSession -Uri $Uri -Body $Json -ContentType $ContentType -Headers $Header

    		# Getting Authentication challenges from initial Response
            $InitialResponseResult = $InitialResponse.Content | ConvertFrom-Json

			$global:InitialResponseResult = $InitialResponseResult
		    if ($InitialResponseResult.Success)
		    {
				# testing for Federation Redirect
				# if the IdpRedirectUrl property is not null or empty
				if (-Not ([System.String]::IsNullOrEmpty($InitialResponseResult.Result.IdpRedirectUrl)))
				{
					# hit the endpoint to trigger federation
					$triggerfederation = Invoke-WebRequest -UseBasicParsing -Method Get -Uri $InitialResponseResult.Result.IdpRedirectUrl -WebSession $PlatformSession -MaximumRedirection 10

					# slightly different version to get the IdP login Uri based on PowerShell version number
					if ($PSVersionTable.PSVersion.Major -eq 7)
					{
						$redirecturiabsolutepath = $triggerfederation.BaseResponse.RequestMessage.RequestUri.AbsoluteUri
					}
					else
					{
						$redirecturiabsolutepath = $triggerfederation.BaseResponse.ResponseUri.AbsoluteUri
					}

					# get the relay state
					$relaystate = $redirecturiabsolutepath -replace '^.*?&RelayState=(.*?)&SigAlg=.*$','$1'

					# getting the SamlResponse, derived from https://github.com/allynl93/getSAMLResponse-Interactive/blob/main/PowerShell%20New-SAMLInteractive%20Module/PS-SAML-Interactive.psm1
					$SamlResponse = New-SAMLInteractive -LoginIDP $redirecturiabsolutepath

					# preparing the body response back to PAS/CloudSuite
					$bodyresponse = ("SAMLResponse={0}&RelayState={1}" -f [System.Web.HttpUtility]::UrlEncode($samlresponse), $relaystate)

					# this is now getting me the 
					$aftersaml = Invoke-WebRequest -UseBasicParsing -Method Post -Uri ('https://{0}/identity-federation/saml/assertion-consumer' -f $Url) -Body ("{0}" -f $bodyresponse) -WebSession $PlatformSession

					# stripping out what we need
					$finalcode  = ([regex]::Match($aftersaml.RawContent,('<input type="hidden" name="code" value="(.*?)" />'),[System.Text.RegularExpressions.RegexOptions]::Singleline).Groups[0].Value) -replace '<input type="hidden" name="code" value="(.*?)" />','$1'
					$finalstate = ([regex]::Match($aftersaml.RawContent,('<input type="hidden" name="state" value="(.*?)" />'),[System.Text.RegularExpressions.RegexOptions]::Singleline).Groups[0].Value) -replace '<input type="hidden" name="state" value="(.*?)" />','$1'
					$finaliss   = ([regex]::Match($aftersaml.RawContent,('<input type="hidden" name="iss" value="(.*?)" />'),[System.Text.RegularExpressions.RegexOptions]::Singleline).Groups[0].Value) -replace '<input type="hidden" name="iss" value="(.*?)" />','$1'

					$finalbodyresponse = ("code={0}&state={1}&iss={2}" -f $finalcode, [System.Web.HttpUtility]::UrlEncode($finalstate), [System.Web.HttpUtility]::UrlEncode($finaliss))

					# endpoint to pass code, state, and iss to signin-oidc
					$signininvoke = Invoke-WebRequest -UseBasicParsing -Method Post -Uri ("https://{0}/identity/signin-oidc" -f $url) -Body ("{0}" -f $finalbodyresponse) -WebSession $PlatformSession

					# finally, hit this endpoint to get the bearer token
					$browseridentity = Invoke-WebRequest -UseBasicParsing -Method Post -Uri ("https://{0}/identity/Security/BrowserIdentity" -f $url) -WebSession $PlatformSession

					# if the initial response was successful
					if ($browseridentity.StatusCode -eq 200)
					{
						$accesstoken = ($browseridentity.Content | ConvertFrom-Json).Result.access_token

						$PlatformConnection = New-Object -TypeName PSCustomObject

						$PlatformConnection | Add-Member -MemberType NoteProperty -Name User -Value $User
						$PlatformConnection | Add-Member -MemberType NoteProperty -Name SessionStartTime -Value $browseridentity.Headers.Date
						$PlatformConnection | Add-Member -MemberType NoteProperty -Name PodFqdn -Value $Url
						$PlatformConnection | Add-Member -MemberType NoteProperty -Name Session -Value $PlatformSession

						# Set Connection as global
						$global:PlatformConnection = $PlatformConnection

						# setting the bearer token header
						$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
						$headers.Add("Authorization","Bearer $accesstoken")

						# setting the splat
						$global:PlatformSessionInformation = @{ Headers = $headers; ContentType = "application/json" }

						return ($PlatformConnection | Select-Object -Property User, PodFqdn, SessionStartTime | Format-List)
					}# if ($browseridentity.StatusCode -eq 200)
				}# if (-Not ([System.String]::IsNullOrEmpty($InitialResponseResult.Result.IdpRedirectUrl)))

			    Write-Debug ("InitialResponse=`n{0}" -f $InitialResponseResult)
                # Go through all challenges
                foreach ($Challenge in $InitialResponseResult.Result.Challenges)
                {
                    # Go through all available mechanisms
                    if ($Challenge.Mechanisms.Count -gt 1)
                    {
                        Write-Host "`n[Available mechanisms]"
                        # More than one mechanism available
                        $MechanismIndex = 1
                        foreach ($Mechanism in $Challenge.Mechanisms)
                        {
                            # Show Mechanism
                            Write-Host ("{0} - {1}" -f $MechanismIndex++, $Mechanism.PromptSelectMech)
                        }
                        
                        # Prompt for Mechanism selection
                        $Selection = Read-Host -Prompt "Please select a mechanism [1]"
                        # Default selection
                        if ([System.String]::IsNullOrEmpty($Selection))
                        {
                            # Default selection is 1
                            $Selection = 1
                        }
                        # Validate selection
                        if ($Selection -gt $Challenge.Mechanisms.Count)
                        {
                            # Selection must be in range
                            Throw "Invalid selection. Authentication challenge aborted." 
                        }
                    }
                    elseif($Challenge.Mechanisms.Count -eq 1)
                    {
                        # Force selection to unique mechanism
                        $Selection = 1
                    }
                    else
                    {
                        # Unknown error
                        Throw "Invalid number of mechanisms received. Authentication challenge aborted."
                    }

                    # Select chosen Mechanism and prepare answer
                    $ChosenMechanism = $Challenge.Mechanisms[$Selection - 1]

			        # Format Json query
			        $Auth = @{}
			        $Auth.InstanceId = $InitialResponseResult.Result.InstanceId
			        $Auth.SessionId = $InitialResponseResult.Result.SessionId
                    $Auth.MechanismId = $ChosenMechanism.MechanismId
                    
                    # Decide for Prompt or Out-of-bounds Auth
                    switch($ChosenMechanism.AnswerType)
                    {
                        "Text" # Prompt User for answer
                        {
                            $Auth.Action = "Answer"
                            # Prompt for User answer using SecureString to mask typing
                            $SecureString = Read-Host $ChosenMechanism.PromptMechChosen -AsSecureString
                            $Auth.Answer = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString))
                        }
                        
                        "StartTextOob" # Out-of-bounds Authentication (User need to take action other than through typed answer)
                        {
                            $Auth.Action = "StartOOB"
                            # Notify User for further actions
                            Write-Host $ChosenMechanism.PromptMechChosen
                        }
                    }
	                $Json = $Auth | ConvertTo-Json
                    
                    # Send Challenge answer
			        $Uri = ("https://{0}/identity/Security/AdvanceAuthentication" -f $Url)
			        $ContentType = "application/json" 
			        $Header = @{ "X-CENTRIFY-NATIVE-CLIENT" = "1" }
			
			        # Send answer
			        $WebResponse = Invoke-WebRequest -UseBasicParsing -Method Post -SessionVariable PlatformSession -Uri $Uri -Body $Json -ContentType $ContentType -Headers $Header
            		
                    # Get Response
                    $WebResponseResult = $WebResponse.Content | ConvertFrom-Json
                    if ($WebResponseResult.Success)
		            {
                        # Evaluate Summary response
                        if($WebResponseResult.Result.Summary -eq "OobPending")
                        {
                            $Answer = Read-Host "Enter code then press <enter> to finish authentication"
                            # Send Poll message to Delinea Identity Platform after pressing enter key
			                $Uri = ("https://{0}/identity/Security/AdvanceAuthentication" -f $Url)
			                $ContentType = "application/json" 
			                $Header = @{ "X-CENTRIFY-NATIVE-CLIENT" = "1" }
			
			                # Format Json query
			                $Auth = @{}
			                $Auth.InstanceId = $Url.Split('.')[0]
			                $Auth.SessionId = $InitialResponseResult.Result.SessionId
                            $Auth.MechanismId = $ChosenMechanism.MechanismId
                            
                            # Either send entered code or poll service for answer
                            if ([System.String]::IsNullOrEmpty($Answer))
                            {
                                $Auth.Action = "Poll"
                            }
                            else
                            {
                                $Auth.Action = "Answer"
                                $Auth.Answer = $Answer
                            }
			                $Json = $Auth | ConvertTo-Json
			
                            # Send Poll message or Answer
			                $WebResponse = Invoke-WebRequest -UseBasicParsing -Method Post -SessionVariable PlatformSession -Uri $Uri -Body $Json -ContentType $ContentType -Headers $Header
                            $WebResponseResult = $WebResponse.Content | ConvertFrom-Json
                            if ($WebResponseResult.Result.Summary -ne "LoginSuccess")
                            {
                                Throw "Failed to receive challenge answer or answer is incorrect. Authentication challenge aborted."
                            }
                        }

                        # If summary return LoginSuccess at any step, we can proceed with session
                        if ($WebResponseResult.Result.Summary -eq "LoginSuccess")
		                {
                            # Get Session Token from successfull login
			                Write-Debug ("WebResponse=`n{0}" -f $WebResponseResult)

							# Get Connection details
							$Connection = $WebResponseResult.Result
			
							# Add session to the Connection
							$Connection | Add-Member -MemberType NoteProperty -Name Session -Value $PlatformSession

							# removing the identity part of the pod FQDN
							$Connection.PodFqdn = $Connection.PodFqdn -replace '/identity',''

							# Set Connection as global
							$Global:PlatformConnection = $Connection

							# setting the bearer token header
							$accesstoken = $Connection.OAuthTokens.access_token
							$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
							$headers.Add("Authorization","Bearer $accesstoken")

							# setting the splat
							$global:PlatformSessionInformation = @{ Headers = $headers; ContentType = "application/json" }

							# if the $PlatformConnections variable does not contain this Connection, add it
							if (-Not ($PlatformConnections | Where-Object {$_.PodFqdn -eq $Connection.PodFqdn}))
							{
								# add a new PlatformConnection object and add it to our $PlatformConnectionsList
								$obj = New-Object PlatformConnection -ArgumentList ($Connection.PodFqdn,$Connection,$global:PlatformSessionInformation)
								$global:PlatformConnections.Add($obj) | Out-Null
							}
			
							# Return information values to confirm connection success
							return ($Connection | Select-Object -Property CustomerId, User, PodFqdn | Format-List)

                        }# if ($WebResponseResult.Result.Summary -eq "LoginSuccess")
		            }# if ($WebResponseResult.Success)
		            else
		            {
                        # Unsuccesful connection
			            Throw $WebResponseResult.Message
		            }
                }# foreach ($Challenge in $InitialResponseResult.Result.Challenges)
		    }# if ($InitialResponseResult.Success)
		    else
		    {
			    # Unsuccesful connection
			    Throw $InitialResponseResult.Message
		    }
		}# else
	}# try
	catch
	{
		Throw $_.Exception
	}
}# function global:Connect-PlatformInstance
#endregion
###########