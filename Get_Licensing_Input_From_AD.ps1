# Script to read the Licensing Information from Active Directory

# Get the RootDSE
$rootDSE = [ADSI]"LDAP://RootDSE"

# Get the defaultNamingContext
$Ldap = "LDAP://" + $rootDSE.defaultNamingContext 

# Create a LicensesInput File
$outFile=".\queuedLicense\LicenseInput_{0:yyyyMMdd-HHmm}.csv" -f (Get-Date)

# Get all users with the EmployeeType Set. If you use another attribute to store the license information change the filter below.
$filter="(&(ObjectClass=user)(ObjectCategory=person)(EmployeeType=*))"

# create the Header for the Output File
$header = "userPrincipalName;O365LicenseType"
$timeStamp = ""

# Check if the file exists and if it does with the same timestamp remove it
if(Test-Path $outFile)
{
  Remove-Item $outFile
}

# create the output file and write the header
Out-File -InputObject $header -FilePath $outFile

#
#	Main routine
#
function GetLicenseInformation()
{
    # create a adsisearcher with the filter
	$searcher = [adsisearcher]$Filter

	# setup the searcher properties
	$searcher.SearchRoot = $Ldap

	# user fields
	$searcher.propertiesToLoad.Add("EmployeeType")
	$searcher.propertiesToLoad.Add("Mail")
	$searcher.propertiesToLoad.Add("userAccountControl")

	# limit per one request
	$searcher.pageSize = 5000

	# find all objects matching the filter
	$results = $searcher.FindAll()

	foreach($result in $results)
	{
		# work through the array and build a custom PS Object
		[Array]$propertiesList = $result.Properties.PropertyNames

		$obj = New-Object PSObject
		
		foreach($property in $propertiesList)
		{ 
			$obj | add-member -membertype noteproperty -name $property -value ([string]$result.Properties.Item($property))
		}
		
		# fiter objects by <userAccountControl> field:
		#
		#	512	Enabled Account
		#	514	Disabled Account
		#	544	Enabled, Password Not Required
		#	546	Disabled, Password Not Required
		#	66048	Enabled, Password Doesn't Expire
		#	66050	Disabled, Password Doesn't Expire
		#	66080	Enabled, Password Doesn't Expire & Not Required
		#	66082	Disabled, Password Doesn't Expire & Not Required
		#	262656	Enabled, Smartcard Required
		#	262658	Disabled, Smartcard Required
		#	262688	Enabled, Smartcard Required, Password Not Required
		#	262690	Disabled, Smartcard Required, Password Not Required
		#	328192	Enabled, Smartcard Required, Password Doesn't Expire
		#	328194	Disabled, Smartcard Required, Password Doesn't Expire
		#	328224	Enabled, Smartcard Required, Password Doesn't Expire & Not Required
		#	328226	Disabled, Smartcard Required, Password Doesn't Expire & Not Required
		if ($obj.userAccountControl -eq 544)
		{	
			# Write the line to the output file
			$i = $obj.Mail +";"+ $obj.EmployeeType
			Out-File -Append -InputObject $i -FilePath $outFile
		}
	}
	return
}

# main routine
GetLicenseInformation
