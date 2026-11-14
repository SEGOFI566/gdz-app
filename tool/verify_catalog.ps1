param(
  [string]$Path = (Join-Path $PSScriptRoot "..\assets\data\catalog.json")
)

# Проверяет catalog.json: валидность JSON, уникальность id и ссылки.
$ErrorActionPreference = "Stop"
$failures = New-Object System.Collections.Generic.List[string]

try {
  $catalog = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
  Write-Host "ОШИБКА: невалидный JSON — $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}

$subjectIds = @($catalog.subjects | ForEach-Object { $_.id })
$textbookIds = @($catalog.textbooks | ForEach-Object { $_.id })
$taskIds = @($catalog.tasks | ForEach-Object { $_.id })

function Check-Unique([string]$name, [string[]]$ids) {
  $dupes = $ids | Group-Object | Where-Object { $_.Count -gt 1 }
  foreach ($dupe in $dupes) {
    $script:failures.Add("${name}: повторяется id '$($dupe.Name)'")
  }
}

Check-Unique "subjects" $subjectIds
Check-Unique "textbooks" $textbookIds
Check-Unique "tasks" $taskIds

foreach ($textbook in $catalog.textbooks) {
  if ($subjectIds -notcontains $textbook.subjectId) {
    $failures.Add("textbook '$($textbook.id)': нет предмета '$($textbook.subjectId)'")
  }
  if ($textbook.grade -lt 1 -or $textbook.grade -gt 11) {
    $failures.Add("textbook '$($textbook.id)': класс вне диапазона 1–11")
  }
}

foreach ($task in $catalog.tasks) {
  if ($textbookIds -notcontains $task.textbookId) {
    $failures.Add("task '$($task.id)': нет учебника '$($task.textbookId)'")
  }
  if (@($task.solutions).Count -eq 0) {
    $failures.Add("task '$($task.id)': нет ни одного решения")
  }
  foreach ($solution in @($task.solutions)) {
    if (@($solution.steps).Count -eq 0) {
      $failures.Add("task '$($task.id)' / solution '$($solution.id)': пустые шаги")
    }
    if ([string]::IsNullOrWhiteSpace($solution.answer)) {
      $failures.Add("task '$($task.id)' / solution '$($solution.id)': пустой ответ")
    }
  }
}

Write-Host "Предметов:  $($subjectIds.Count)"
Write-Host "Учебников:  $($textbookIds.Count)"
Write-Host "Заданий:    $($taskIds.Count)"

if ($failures.Count -gt 0) {
  Write-Host ""
  Write-Host "Найдены проблемы:" -ForegroundColor Red
  foreach ($failure in $failures) {
    Write-Host "  - $failure" -ForegroundColor Red
  }
  exit 1
}

Write-Host ""
Write-Host "OK: каталог корректен" -ForegroundColor Green
