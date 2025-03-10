# 获取当前 Git 工作目录中修改的 .rs 文件
$modifiedFiles = git diff --name-only HEAD | Where-Object { $_ -match '\.rs$' }

if (-not $modifiedFiles) {
    Write-Output "No modified Rust files found."
    exit 0
}

# 设置最大并行线程数（根据 CPU 核心数调整，例如 4 或 8）
$maxThreads = 32

# 创建作业列表
$jobs = @()
foreach ($file in $modifiedFiles) {
    # 为每个文件启动一个后台作业
    $jobs += Start-Job -ScriptBlock {
        param($file)
        $output = & cargo check --quiet --message-format=json -- $file 2>&1
        return [PSCustomObject]@{
            File = $file
            Output = $output
        }
    } -ArgumentList $file

    # 限制并行作业数
    while ((Get-Job -State Running).Count -ge $maxThreads) {
        Start-Sleep -Milliseconds 100
    }
}

# 等待所有作业完成并收集结果
$results = $jobs | Wait-Job | Receive-Job
Remove-Job -Job $jobs -Force

# 输出所有检查结果
foreach ($result in $results) {
    Write-Output "File: $($result.File)"
    Write-Output $result.Output
}