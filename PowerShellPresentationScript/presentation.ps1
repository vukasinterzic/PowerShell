<#PowerShell Presentation
#This is now static presentation that I made quickly for one time use. 
#Idea is to make this concept ready for dynamci content creation and customization
#>

#TODO Make input file generator
#TODO Generate ASCII titles dynamically
#TODO Add Error-handling
#TODO Add description here and in readme file

#Content
#Slide 1:

$PowerShellCore = (Invoke-WebREquest "http://artii.herokuapp.com/make?text=PowerShell+Core").Content
$PwSh = (Invoke-WebREquest "http://artii.herokuapp.com/make?text=PwSh.exe?").Content
$Rozdily = (Invoke-WebREquest "http://artii.herokuapp.com/make?text=Rozdily").Content
$PoShPwSh = (Invoke-WebREquest "http://artii.herokuapp.com/make?text=PoSh+vs+PwSh").Content
$PowerShell7 = (Invoke-WebREquest "http://artii.herokuapp.com/make?text=PowerShell+7").Content
$Demo = (Invoke-WebREquest "http://artii.herokuapp.com/make?text=Demo").Content
$Zaver = (Invoke-WebREquest "http://artii.herokuapp.com/make?text=Zaver").Content

function Slide0 {

    Clear-Host
    
    Write-Host -ForegroundColor DarkCyan $PowerShellCore
    $Content =@()
    $Content += @(
        "       1. Co to je PowerShell Core, PowerShell 6, PwSh.exe?",
        "       2. Rozdily mezi PowerShell a PowerShell Core",
        "       3. Demo",
        "", "", "", "", "", "","", "")
    
    $Content
}


function Slide1 {

    Clear-Host
    Write-Host -ForegroundColor DarkCyan $PwSh
    $Content = @()
    $Content += (
        "   1. Prvni pouziti ve WS2016 Nano, samostatne od roku 2018",
        "   2. Nova generace PowerShell, neni to upgrade stavajici", 
        "   3. .NET Core misto full .NET Framework",
        "   4. OpenSource",
        "", "", "", "", "", "","")
    $Content
    
}

function Slide2 {

    Clear-Host
    Write-Host -ForegroundColor DarkCyan $Rozdily
    $Content = @()
    $Content += (
        "   1. Technologie, open source, multiplatform, ...", 
        "   2. Pocet Cmdletu",
        "   3. Podpora modulu",
        "   4. Rozdily ve stejnych Cmdletech",
        "   5. SSH Remoting",
        "", "", "", "", "","")
    $Content
    
}

function Slide3 {

    Clear-Host
    Write-Host -ForegroundColor DarkCyan $PoShPwSh
    
    $tabulka = Import-Csv -Path "C:\Scripts\TechOb\table1.csv"

    Write-Host "BuiltIn Cmdlets"
    $tabulka | Format-Table

    Write-Host "(Get-Command -Name *-* -CommandType Cmdlet, Function).Count"
    Write-Host "`n`n`n"

}

function Slide4 {

    Clear-Host
    Write-Host -ForegroundColor DarkCyan $PoShPwSh
    
    $tabulka = Import-Csv -Path "C:\Scripts\TechOb\table2.csv"

    Write-Host "BuiltIn Cmdlets + RSAT"
    $tabulka | Format-Table

    Write-Host "(Get-Command -Name *-* -CommandType Cmdlet, Function).Count"
    Write-Host "`n`n`n"
    
}

function Slide5 {

    Clear-Host
    Write-Host -ForegroundColor DarkCyan $PoShPwSh
    $Content = @()
    $Content += (
        "   Priklad podporovanych modulu: AZ",
        "",
        "   Priklad nepodporovanych modulu: ActiveDirectory",
        "", 
        "   Jak to vyresit:", 
        "   Import-Module <moduleName> -SkipEditionCheck", 
        "   Get-ExperimentalFeature | Enable-ExperimentalFeature",
        "   Invoke-Command -Session `$S1 -ScriptBlock { Get-ADDomain }",
        "","","")
    $Content
    
}

function Slide6 {

    Clear-Host
    Write-Host -ForegroundColor DarkCyan $PowerShell7
    $Content = @()
    $Content += (
        "   1. Proc uz to neni Core?",
        "   2. 90% PoSH 5.1",
        "   3. Shipping in Windows?",
        "   3. Diky",
        "", "", "", "", "", "","")
    $Content 
}


function Slide7 {

    Clear-Host
    Write-Host -ForegroundColor DarkCyan $Demo
    $Content = @()
    $Content += (
        "   1. Windows, MacOS, Linux, Azure",
        "   2. Cmdlets",
        "   3. Azure Function App",
        "   4. ?", 
        "", "", "", "", "","", "")
    $Content 
}

function Slide8 {

    Clear-Host
    Write-Host -ForegroundColor DarkCyan $Zaver
    $Content = @()
    $Content += (
        "   1. Pouzivat nebo ne?",
        "   2. Updates",
        "   3. GitHub",
        "   4. Diky", 
        "", "", "", "", "","", "")
    $Content 
}


$selection = ""
$n = 0
$slideCount = 8

Invoke-Expression Slide0

while ($selection -ne "Q") {
    #runs untill you enter Q

    If ($selection -eq "n") {
        $n++
        $Slide = "Slide$n"
        Invoke-Expression $Slide
    
    }
    elseif ($selection -eq "p") {
        $n--
        $Slide = "Slide$n"
        Invoke-Expression $Slide  
    }


    if ($n -eq 0) {

        #prvni slide
        #multi color one line message
        Write-Host -ForegroundColor DarkGray "Prvni slide. Dalsi slide " -NoNewline
        Write-Host -ForegroundColor DarkCyan "n" -NoNewline
        Write-Host -ForegroundColor DarkGray ", konec prezentace " -NoNewline
        Write-Host -ForegroundColor DarkCyan "q" -NoNewline
        Write-Host -ForegroundColor DarkGray " : " -NoNewline
        $selection = Read-Host #read user input

    } elseif ($n -ge $slideCount) {

        #posledni slide
        #multi color one line message
        Write-Host -ForegroundColor DarkGray "Posledni slide. Predchozi slide " -NoNewline
        Write-Host -ForegroundColor DarkCyan "p" -NoNewline
        Write-Host -ForegroundColor DarkGray ", konec prezentace " -NoNewline
        Write-Host -ForegroundColor DarkCyan "q" -NoNewline
        Write-Host -ForegroundColor DarkGray " : " -NoNewline
        $selection = Read-Host #read user input

    } else {

        #multi color one line message
        Write-Host -ForegroundColor DarkGray "Dalsi slide " -NoNewline
        Write-Host -ForegroundColor DarkCyan "n" -NoNewline
        Write-Host -ForegroundColor DarkGray ", predchozi slide " -NoNewline
        Write-Host -ForegroundColor DarkCyan "p" -NoNewline
        Write-Host -ForegroundColor DarkGray ", konec prezentace " -NoNewline
        Write-Host -ForegroundColor DarkCyan "q" -NoNewline
        Write-Host -ForegroundColor DarkGray " : " -NoNewline
        $selection = Read-Host #read user input
    }
}

Clear-Host
