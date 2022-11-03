Param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Stop","Start")]
    [string] $Instruction
)

Get-AzVM | % {
    $name = ($_.Id).Split("/")[-1]
    Write-Host $name -f yellow
    
    $forceParam = if ($Instruction -eq "Stop") { "-Force" }
    
    $cmd = "$Instruction-AzVM -name $name -ResourceGroupName $($_.ResourceGroupName) $forceParam"
    Invoke-Expression $cmd
}