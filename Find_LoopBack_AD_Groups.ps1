# Указываем место для сохранения файла-отчёта:
$pathToSaveCSV = "C:\Reports\loopbackAdGroups.csv"

# Производим проверку на существование файла в этом расположении:
IF (Test-Path ($pathToSaveCSV)) {
    Write-Host "File already exists" -ForegroundColor Red
    Break
}

# Производим выгрузку всех групп AD в переменную, с которой будем работать дальше:
$adGroups = Get-ADGroup -Filter * -Properties Members, MemberOf, objectClass, GroupCategory, GroupScope, mail

# Дополнительно указываем переменные для просмотра процесса выполнения скрипта:
$adGroupsCount = $adGroups.Count
$counter = 1

# Приступаем к поиску зацикливающихся групп в AD:
foreach ($groupCheck in $adGroups) {
    Write-Host "Proccessing group $counter/$adGroupsCount" -ForegroundColor Cyan # Вывод процесса выполнения скрипта
    $childGroups = @() # Инициализация массива для дочерних групп
    $parentGroups = @() # Инициализация массива для родительских групп

    $childGroups += $groupCheck.Members | Get-ADGroup -Properties Members, objectClass, GroupCategory, GroupScope, mail -ErrorAction SilentlyContinue # Дочерние группы
    $parentGroups += $groupCheck.MemberOf | Get-ADGroup -Properties MemberOf, objectClass, GroupCategory, GroupScope, mail # Родительские группы

    # Ищем все дочерние группы:
    $passedGroups = @()
    DO {
        $difference = ((Compare-Object -ReferenceObject $childGroups -DifferenceObject $passedGroups).InputObject)
        foreach ($i in $difference) {
            IF ($Temp = $i.Members | Get-ADGroup -Properties Members, objectClass, GroupCategory, GroupScope, mail -ErrorAction SilentlyContinue) {
                foreach ($j in $Temp) {
                    IF ($childGroups.Name -NotContains $j.Name) {
                        $childGroups += $j
                    }
                }
            }
            $passedGroups += $i
        }
    }
    While ($difference -ne $null)

    # Ищем все родительские группы:
    $passedGroups = @()
    DO {
        $difference = ((Compare-Object -ReferenceObject $parentGroups -DifferenceObject $passedGroups).InputObject)
        foreach ($i in $difference) {
            IF ($Temp = $i.MemberOf | Get-ADGroup -Properties MemberOf, objectClass, GroupCategory, GroupScope, mail) {
                foreach ($j in $Temp) {
                    IF ($parentGroups.Name -NotContains $j.Name) {
                        $parentGroups += $j
                    }
                }
            }
            $passedGroups += $i
        }
    }
    While ($difference -ne $null)

    # Проходим повторно по всем дочерним группам и выявляем зацикливание:
    $childLoopbackGroups = @()
    foreach ($childGroup in $childGroups) {
        $childGroupsLoopbackFind = @()
        $childGroupsLoopbackFind += $childGroup.Members | Get-ADGroup -Properties Members, objectClass, GroupCategory, GroupScope, mail -ErrorAction SilentlyContinue # Дочерние группы
        $passedGroups = @() 
        DO {
            $difference = ((Compare-Object -ReferenceObject $childGroupsLoopbackFind -DifferenceObject $passedGroups).InputObject)
            foreach ($i in $difference) {
                IF ($Temp = $i.Members | Get-ADGroup -Properties Members, objectClass, GroupCategory, GroupScope, mail -ErrorAction SilentlyContinue) {
                    foreach ($j in $Temp) {
                        IF ($childGroupsLoopbackFind.Name -NotContains $j.Name) {
                            $childGroupsLoopbackFind += $j
                        }
                    }
                }
                $passedGroups += $i
            }
        }
        While ($difference -ne $null)

        IF ($childGroup.Name -in $childGroupsLoopbackFind.Name) {
            $childLoopbackGroups += $childGroup.Name
        }
    }

    # Проходим повторно по всем родительским группам и выявляем зацикливание:
    $parentLoopbackGroups = @()
    foreach ($parentGroup in $parentGroups) {
        $parentGroupsLoopbackFind = @()
        $parentGroupsLoopbackFind += $parentGroup.MemberOf | Get-ADGroup -Properties MemberOf, objectClass, GroupCategory, GroupScope, mail # Родительские группы
        $passedGroups = @() 
        DO {
            $difference = ((Compare-Object -ReferenceObject $parentGroupsLoopbackFind -DifferenceObject $passedGroups).InputObject)
            foreach ($i in $difference) {
                IF ($Temp = $i.MemberOf | Get-ADGroup -Properties MemberOf, objectClass, GroupCategory, GroupScope, mail) {
                    foreach ($j in $Temp) {
                        IF ($parentGroupsLoopbackFind.Name -NotContains $j.Name) {
                            $parentGroupsLoopbackFind += $j
                        }
                    }
                }
                $passedGroups += $i
            }
        }
        While ($difference -ne $null)

        IF ($parentGroup.Name -in $parentGroupsLoopbackFind.Name) {
            $parentLoopbackGroups += $parentGroup.Name
        }
    }
    
    # Производим выгрузку полученных данных по группе в CSV-файл по пути, указанному в самом начале скрипта:
    $groupCheck | Select-Object Name, SamAccountName, DisplayName, objectClass, GroupCategory, GroupScope, mail, @{ N = "Child Groups in loop"; E = {$childLoopbackGroups -Join '; '}}, @{ N = "Parent Groups in loop"; E = {$parentLoopbackGroups -Join '; '}}, @{ N = "Loopback was found"; E = { IF ($childLoopbackGroups -OR $parentLoopbackGroups) {"+"} Else {"-"} }} | Export-CSV $pathToSaveCSV -Encoding UTF8 -Delimiter ';' -NoTypeInformation -Append
    
    # Увеличиваем счётчик для мониторинга процесса выполнения:
    $counter += 1
}
