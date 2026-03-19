# 设置文件路径
$oldEnFile = "keys - 0.14.3.txt"
$newEnFile = "keys - 0.14.8.txt"
$oldCnFile = "keys - 0.14.3-CN.txt"
$newCnFile = "keys - 0.14.8-CN-NEW.txt"
$csvFile = "对比结果.csv"

# 检查文件是否存在
if (-not (Test-Path $oldEnFile)) { Write-Host "错误：找不到文件 '$oldEnFile'" -ForegroundColor Red; exit }
if (-not (Test-Path $newEnFile)) { Write-Host "错误：找不到文件 '$newEnFile'" -ForegroundColor Red; exit }
if (-not (Test-Path $oldCnFile)) { Write-Host "错误：找不到文件 '$oldCnFile'" -ForegroundColor Red; exit }

# 读取文件内容到哈希表
function Read-FileToHash($path) {
    $hash = @{}
    Get-Content $path -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $firstSpace = $line.IndexOf(' ')
            if ($firstSpace -gt 0) {
                $key = $line.Substring(0, $firstSpace)
                $value = $line.Substring($firstSpace + 1).Trim()
                $hash[$key] = $value
            }
        }
    }
    return $hash
}

Write-Host "读取文件..."
$oldEn = Read-FileToHash $oldEnFile
$oldCn = Read-FileToHash $oldCnFile

# 读取新英文文件，同时记录行号和完整行列表
Write-Host "读取新英文文件并记录行号..."
$newEn = @{}
$newEnLineNumber = @{}
$newEnLines = Get-Content $newEnFile -Encoding UTF8
$lineNum = 0
foreach ($line in $newEnLines) {
    $lineNum++
    $trimmed = $line.Trim()
    if ($trimmed -and -not $trimmed.StartsWith('#')) {
        $firstSpace = $line.IndexOf(' ')
        if ($firstSpace -gt 0) {
            $key = $line.Substring(0, $firstSpace)
            $value = $line.Substring($firstSpace + 1).Trim()
            $newEn[$key] = $value
            $newEnLineNumber[$key] = $lineNum
        }
    }
}

Write-Host "对比英文版本..."
$allKeys = $oldEn.Keys + $newEn.Keys | Select-Object -Unique
$results = @()

foreach ($key in $allKeys) {
    $hasOld = $oldEn.ContainsKey($key)
    $hasNew = $newEn.ContainsKey($key)

    if ($hasOld -and -not $hasNew) {
        $results += [PSCustomObject]@{
            LineNumber = $null
            Key        = $key
            English    = $oldEn[$key]
            Change     = "删除"
            Version    = $oldEnFile
        }
    }
    elseif (-not $hasOld -and $hasNew) {
        $results += [PSCustomObject]@{
            LineNumber = $newEnLineNumber[$key]
            Key        = $key
            English    = $newEn[$key]
            Change     = "新增"
            Version    = $newEnFile
        }
    }
    elseif ($hasOld -and $hasNew) {
        if ($oldEn[$key] -ne $newEn[$key]) {
            $results += [PSCustomObject]@{
                LineNumber = $newEnLineNumber[$key]
                Key        = $key
                English    = $newEn[$key]
                Change     = "变更"
                Version    = $newEnFile
            }
        }
    }
}

# 排序：有行号的按行号升序在前，无行号的（删除条目）按 Key 排序在后
$results = $results | Sort-Object @{Expression={if($_.LineNumber -eq $null){1}else{0}}},
                                     @{Expression={$_.LineNumber}},
                                     @{Expression={$_.Key}}

Write-Host "导出对比结果到 CSV..."
$results | Select-Object LineNumber, Key, English, Change, Version |
    Export-Csv $csvFile -NoTypeInformation -Encoding UTF8

Write-Host "更新中文翻译文件..."

# 复制旧中文哈希表，准备修改
$newCn = $oldCn.Clone()

# 处理新增条目：添加 key，中文暂时填充为英文
foreach ($key in ($results | Where-Object { $_.Change -eq "新增" }).Key) {
    if (-not $newCn.ContainsKey($key)) {
        $newCn[$key] = $newEn[$key]   # 英文作为临时翻译
    }
}

# 处理删除条目：移除对应 key
foreach ($key in ($results | Where-Object { $_.Change -eq "删除" }).Key) {
    if ($newCn.ContainsKey($key)) {
        $newCn.Remove($key)
    }
}

# 变更条目保持原中文不变，无需操作

Write-Host "写入新中文文件：$newCnFile（按最新英文文件行顺序）"

# 按新英文文件的行顺序生成中文文件
$outputLines = @()
foreach ($line in $newEnLines) {
    $trimmed = $line.Trim()
    # 保留空行或注释行（文件开头可能有 BOM 或注释，这里简单判断）
    if ($trimmed -eq "" -or $trimmed.StartsWith('#')) {
        $outputLines += $line
    } else {
        $firstSpace = $line.IndexOf(' ')
        if ($firstSpace -gt 0) {
            $key = $line.Substring(0, $firstSpace)
            if ($newCn.ContainsKey($key)) {
                $outputLines += "$key $($newCn[$key])"
            } else {
                # 理论上不会发生，但若发生则保留原英文行
                $outputLines += $line
            }
        } else {
            # 没有空格的行（格式异常），原样保留
            $outputLines += $line
        }
    }
}

$outputLines | Set-Content $newCnFile -Encoding UTF8

Write-Host "全部完成！"