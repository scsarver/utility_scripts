SHELL=/bin/bash
SCOUTSUITE_PATH="./ScoutSuite"
VENV_DIR="scout-venv"

usage:
	@echo "USAGE:"
	@echo " "
	@echo '   $$ make <target_name>'
	@echo " "
	@echo " Targets: "
	@echo " "
	@echo "  [help] - This target shows helpful hints and remediations for errors"
	@echo "           that can occour when using this make file."
	@echo " "
	@echo "  [python-version] - to see the python versions installed."
	@echo "                     Note: This make file uses python3 as the python executable(link)"
	@echo "                     due to the python executable(link) version is 2.7."
	@echo " "
	@echo "  [python-make-venv] - to setup the venv virtual environment in this directory"
	@echo "                       that scout will execute in."
	@echo " "
	@echo "  [scout-clone] - to pull down the source code that will be used to run scout."
	@echo " "
	@echo "  [scout-init] - to activate the venv virtual environment, install the required"
	@echo "                 pips, and then output the version of scout."
	@echo " "
	@echo "  [scout-help] - to display the scout help."
	@echo " "
	@echo "  [scout-aws-help] - to display the scout help for the aws provider."
	@echo " "
	@echo "  [scout-version] - to display the version of scout."
	@echo " "
	@echo "  [scout-run] - to run scout against the account associated to the AWS_PROFILE"
	@echo "                enviropnment variable. Note: we are defaulting to run scout in the us-east-1 region."
	@echo " "
	@echo "  [references] - to display links that were helpful in making this make file."
	@echo " "

help:
	@echo " "
	@echo " Getting started:"
	@echo "    Starting fresh the first requirement is that you have Python3 as your python executable"
	@echo "    python at version 3.X. You can check you version by running the following target [python-version]"
	@echo " "
	@echo " "
	@echo " "
	@echo " "
	@echo "What do these errors mean:"
	@echo " "
	@echo "  ModuleNotFoundError:"
	@echo "    '/bin/bash: ./scout-venv/bin/activate: No such file or directory'"
	@echo "    '/bin/bash: pip: command not found'"
	@echo "    '/bin/bash: pip: command not found'"
	@echo "    ..."
	@echo "    'ModuleNotFoundError: No module named 'asyncio_throttle''"
	@echo " "
	@echo "    This error will show up if you have not run the make target [python-make-venv]."
	@echo "    This target sets up the virtual python environment where you will then run your [scout-init]"
	@echo "    target to install the python pips the ScoutSuite requires in order to run."
	@echo " "


python-version:
	@python --version
	@python3 --version

python-make-venv:
	python3 -m venv ./$(VENV_DIR)

scout-clone:
		git clone https://github.com/nccgroup/ScoutSuite

scout-init:
	@source ./$(VENV_DIR)/bin/activate; \
	cd $(SCOUTSUITE_PATH); \
	pip install -r requirements.txt; \
	python3 ./scout.py --version

scout-help:
	@source ./$(VENV_DIR)/bin/activate; \
	cd $(SCOUTSUITE_PATH); \
	python3 ./scout.py --help

scout-aws-help:
	@source ./$(VENV_DIR)/bin/activate; \
	cd $(SCOUTSUITE_PATH); \
	python3 ./scout.py aws --help

scout-version:
	@source ./$(VENV_DIR)/bin/activate; \
	cd $(SCOUTSUITE_PATH); \
	python3 ./scout.py --version

scout-run:
	@source ./$(VENV_DIR)/bin/activate; \
	if [ "" == "$(AWS_PROFILE)" ]; then \
	echo " "; \
		echo "Error: AWS_PROFILE environment variable is required to be set!"; \
		echo " "; \
	else \
	echo "AWS_PROFILE: $(AWS_PROFILE)"; \
	  cd $(SCOUTSUITE_PATH); \
	  python3 ./scout.py aws --profile $(AWS_PROFILE) -r REGIONS us-east-1; \
	fi \

references:
	@echo "https://makefiletutorial.com"
	@echo "https://github.com/nccgroup/ScoutSuite/wiki"
	@echo "https://github.com/nccgroup/ScoutSuite/wiki/Setup"
