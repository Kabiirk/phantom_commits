echo Hello World !
read -p "Enter Commit message : " mssg
read -p "Enter Commit date : " date
echo $mssg
echo $date

# git checkout master
# git checkout --orphan new-root
# git rm -rf .
# git add path/to/file
# GIT_AUTHOR_DATE='$1' GIT_COMITTER_DATE='$1' git commit
# git checkout -
# git rebase --root --onto new-root
# git branch -d new-root

# Ref :
# https://stackoverflow.com/questions/3895453/how-do-i-make-a-git-commit-in-the-past
# https://stackoverflow.com/questions/23609991/git-github-commit-at-past-date
# https://leewc.com/articles/making-past-git-commits/