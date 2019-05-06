@setlocal
@set repo_dir=%~dp0.
@copy /-Y "%repo_dir%\#githooks"\* "%repo_dir%\.git\hooks"
