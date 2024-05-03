# Задаём исходные данные в переменные:
#$pathRootDir = "C:\Data" # Указываем корневую папку для проверки
#$pathToSaveCSV = "C:\Reports\CheckFoldersACL.csv" # Расположение сохраняемого файла CSV

$pathRootDir = $(Write-Host "Введите путь к проверяемой папке (For Example: C:\Data): " -ForegroundColor Yellow; Read-Host)
# Проверка папки на существование:
IF (!(Test-Path $pathRootDir)) {
	Write-Host "Folder is not exists" -ForegroundColor Red
	Break
}

$pathToSaveCSV = $(Write-Host "Введите путь к файлу для сохранения отчёта (For Example: C:\Reports\CheckFoldersACL.csv): " -ForegroundColor Yellow; Read-Host)
# Проверка на наличие файла с таким же названием:
IF ((Test-Path ($pathToSaveCSV)) -OR !(Test-Path (Split-Path $pathToSaveCSV))) {
    Write-Host "File already exists or bad path to file" -ForegroundColor Red
    Break
}

# Очищаем встроенную переменную Error от возможных прошлых ошибок консоли:
$Error.Clear()

# Выгружаем все подпапки:
$subfolders = Get-ChildItem $pathRootDir -Directory -Recurse -ErrorAction SilentlyContinue | Select-Object PSPath, FullName

# Делаем какой-никакой счётчик обрабатываемых объектов для подсчёта процесса выполнения скрипта:
$subfoldersCount = $subfolders.Count
$counter = 1

# Выгружаем информацию по подпапкам:
foreach ($folder in $subfolders) {
	Write-Host "Proccessing folder $counter/$subfoldersCount" -ForegroundColor Cyan
	
	Try {
		$folder | Get-ACL -ErrorAction SilentlyContinue | Select-Object `
		@{N = "Path"; E = {Convert-Path $_.Path}}, `
		@{N = "Access_Users"; E = {$_.Access.IdentityReference -join '; '}}, `
		@{N = "Access_Type"; E = {$_.Access.AccessControlType -join '; '}}, `
		@{N = "Access_Rights"; E = {$_.Access.FileSystemRights -join '; '}}, `
		@{N = "Access_Contains_Uninherited"; E = { IF ($false -in ($_.Access.IsInherited)) {"+"} Else {"-"}}}, `
		Owner, `
		@{N = "Disabled_Inheritance"; E = {$_.AreAccessRulesProtected}}, `
		@{N = "No_Access_To_Folder"; E = { IF ((Convert-Path $_.Path) -in $Error.TargetObject) {"+"} Else {"-"} }} `
		| Export-CSV $pathToSaveCSV -Encoding UTF8 -Delimiter ';' -NoTypeInformation -Append
	}
	Catch
	{
		$folder | Select-Object `
		@{N = "Path"; E = {$_.FullName}}, `
		@{N = "Access_Users"; E = {"Unknown"}}, `
		@{N = "Access_Type"; E = {"Unknown"}}, `
		@{N = "Access_Rights"; E = {"Unknown"}}, `
		@{N = "Access_Contains_Uninherited"; E = {"Unknown"}}, `
		@{N = "Owner"; E = {"Unknown"}}, `
		@{N = "Disabled_Inheritance"; E = {"Unknown"}}, `
		@{N = "No_Access_To_Folder"; E = {"+"}} `
		| Export-CSV $pathToSaveCSV -Encoding UTF8 -Delimiter ';' -NoTypeInformation -Append
	}
	
	$counter += 1
}
