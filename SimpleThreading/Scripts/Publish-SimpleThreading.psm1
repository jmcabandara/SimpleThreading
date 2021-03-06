$Assem = (
    "System.Xml"
)

$Source = @"
using System;
using System.Xml;

namespace GPS.SimpleThreading.Build
{
	public static class Nuspec
	{
		public static void SetReleaseNotes(string nuspecPath, string releaseNotes)
		{
			XmlDocument nuspec = new XmlDocument();
			
			nuspec.Load(nuspecPath);

			var releaseNotesNode = nuspec.DocumentElement.SelectSingleNode("descendant::releaseNotes");

			if(releaseNotesNode != null)
			{
				releaseNotesNode.InnerText = releaseNotes;

				nuspec.Save(nuspecPath);
			}
		}
	}
}
"@

Add-Type -ReferencedAssemblies $Assem -TypeDefinition $Source -Language CSharp

function Publish-SimpleThreading {
    param(
        [Parameter(Mandatory = $true)][string]$Namespace,
        [Parameter(Mandatory = $true)][string]$ApiKey,
        [Parameter()][string]$SolutionDir = ".",
        [Parameter()][string]$Url = "https://www.nuget.org",
        [Parameter()][string]$Endpoint = "/api/v2/package",
        [Parameter()][switch]$Simulate = $false
    )	

    $releaseNotes = [IO.File]::ReadAllText($SolutionDir + "\ReleaseNotes.txt");
    $nuspecPath = [IO.Path]::Combine($SolutionDir, $Namespace);
    $nuspecFile = [IO.Path]::Combine($SolutionDir, $Namespace, $Namespace + ".nuspec");

    [GPS.SimpleThreading.Build.Nuspec]::SetReleaseNotes($nuspecFile, $releaseNotes);

    Get-Item $nuspecFile | Select-Xml  -XPath "//project"

    & nuget pack $nuspecPath -Build -OutputDirectory .\Assets -Symbols -Properties Configuration=Release

    if ($LASTEXITCODE -eq 0) {

        $nugetSymbolFiles = ".\Assets\" | Get-ChildItem -Filter "*.symbols.nupkg" 
        $nugetFile = (".\Assets\" | Get-ChildItem -Exclude $nugetSymbolFiles | Get-Item -Include ".nupkg" | Sort-Object -Descending | Select-Object -First 1).FullName
        $nugetSymbolFile = ($nugetSymbolFiles | Sort-Object -Descending | Select-Object -First 1).FullName

        Write-Host $nugetFile

        if (-not $Simulate) {
            & nuget push $nugetFile -ApiKey $ApiKey -Source $Url 
        }
        else {
            $simulation = '"nuget push ' + $nugetFile + ' -ApiKey ' + $ApiKey + ' -Source ' + $Url + '"'
            Write-Host $simulation
        }

        Write-Host $nugetSymbolFile

        if (-not $Simulate) {
            & nuget push $nugetFile -ApiKey $ApiKey -Source $Url 
        }
        else {
            $simulation = '"nuget push ' + $nugetSymbolFile + ' -ApiKey ' + $ApiKey + ' -Source ' + $Url + '"'
            Write-Host $simulation
        }
	}
}

Export-ModuleMember -Function *