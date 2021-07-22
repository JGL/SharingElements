# BodyElements

An interactive body tracking installation

## Getting Started

Hardware requirements: MacOS computer (preferably (M1 chip)[https://en.wikipedia.org/wiki/Apple_M1] based machine) and either built in FaceTime camera or external Webcam.

Hardware specification for installation version:
* [M1 Mac Mini with 16Gb memory and 256Gb hard drive](https://www.apple.com/mac-mini/specs/)
* [Logitech Brio Stream Webcam, Ultra HD 4K Streaming Edition](https://www.logitech.com/en-us/products/webcams/brio-4k-hdr-webcam.960-001105.html)

Software requirements:
* A GitHub account
* [macOS 11.4 "Big Sur"](https://en.wikipedia.org/wiki/MacOS_Big_Sur)
* [Xcode 12.5 or above](https://apps.apple.com/us/app/xcode/id497799835?mt=12)
* Xcode command line tools, which can be installed via the command: ```xcode-select --install```
* Command line access via SSH to your GitHub account. [See this guide to connecting to GitHub with SSH](https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh).

Software installation instructions:

Open [Terminal](https://en.wikipedia.org/wiki/Terminal_(macOS)) and create a folder using the [mkdir](https://en.wikipedia.org/wiki/Mkdir) command for the project in a place of your choosing:

```
mkdir BodyElementsInstallation
```

Use the [cd](https://en.wikipedia.org/wiki/Cd_(command)) command to open the folder you just created:

```
cd BodyElementsInstallation
```

If you haven't already done so, install [Homebrew](https://brew.sh/) via the following command:

```
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

Now install [rbenv](https://github.com/rbenv/rbenv) and [ruby-build](https://github.com/rbenv/ruby-build) via Homebrew, to allow your computer to have multiple versions of Ruby installed:

```
brew install rbenv ruby-build
```

Add rbenv to ZSH so that it loads every time you open a terminal: (P.S. we love [Oh My Zsh](https://ohmyz.sh))

```
echo 'if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi' >> ~/.zshrc
source ~/.zshrc
```

Install Ruby 3.0.1:

```
rbenv install 3.0.1
rbenv global 3.0.1
ruby -v
```

N.B. If ruby -v doesn't report 3.0.1, you may have to restart Terminal.app in order for it to be reported correctly. Clone [this repository](https://github.com/JGL/BodyElements/) using the git clone command:

```
git clone git@github.com:JGL/BodyElements.git
```

Clone the [Satin](https://github.com/Hi-Rez/Satin), [Forge](https://github.com/Hi-Rez/Forge) & [Youi](https://github.com/Hi-Rez/Youi) repositories:

```
git clone git@github.com:Hi-Rez/Satin.git && git clone git@github.com:Hi-Rez/Forge.git && git clone git@github.com:Hi-Rez/Youi.git
```

Install [Bundler](https://bundler.io/) using:

```
sudo gem install bundler
```

Use the [cd](https://en.wikipedia.org/wiki/Cd_(command)) command to open the folder that the first git clone command created:

```
cd BodyElements
```

Install the Bundler dependencies specified in the [Gemfile](https://guides.cocoapods.org/using/a-gemfile.html):

```
bundle config set path vendor/bundle
bundle install
```

Install the [CocoaPod](https://cocoapods.org/) dependencies using Bundler:

```
bundle exec pod install
```

Finally, make sure to open the Xcode workspace, not the Xcode project:

```
open BodyElements.xcworkspace
```
