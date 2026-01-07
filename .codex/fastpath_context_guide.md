I am writing a learning path which utilizes HUGO-based files found in https://github.com/geremyCohen/arm-learning-paths, cloned locally at /Users/gercoh01/kustomer/arm-learning-paths.  

All AWS CLI commands must run with `AWS_DEFAULT_PROFILE=arm` targeting the us-east-1 region unless explicitly stated otherwise.

For all work related to this learning path, use branch kernel_lp.

The new learning path (LP) will be written in the https://github.com/geremyCohen/arm-learning-paths/tree/main/content/learning-paths/servers-and-cloud-computing/fastpath folder.  The new LP is to be called "Fastpath Kernel Build and Install Guide".  It will walk the user through a simple use case, based on official documentation located at Official Fastpath (FP) documentation is at https://fastpath.docs.arm.com/en/latest/index.html.  

Review the other LPs under servers-and-cloud-computing for structure and style when creating the new LP.

https://github.com/geremyCohen/arm_kernel_install_guide - This is where the supporting files are kept, namely the tuxmake logic (kernel build and compile). Its cloned locally at /Users/gercoh01/kustomer/arm_kernel_install_guide.  Do not make changes to this repo without explicit permission for each case.  Its considered frozen except for tests and urgent fixes.

You can work in the main branch for this repo.

/Users/gercoh01/kustomer/arm-learning-paths/content/install-guides/kernel-build.md contains the newly created "kernel install guide", which can be used for Fastpath and non-Fastpath kernel builds.  When working with the new LP, the user is instructed to follow specific (Fastpath) sections of this install guide.

For all work related to the install guide, make changes in the kernel_install_guide branch.

Use the .codex/* folders under each of the above, where they exist, as neccesary.

We will help the user accomplish a simplified version of https://fastpath.docs.arm.com/en/latest/index.html.  In order to achieve this, some steps may seem out of order when compared to the I want to walk the user through the following functionally in the LP:

0. create an intro section that explains what kernels are, how they are built, and some simple example use cases of when its handy to compare performance with them (less than 3).

Then discuss how in this tutorial, we'll show them how to build two seperate kernels using tuxmake, and use Fastpath to deploy and test their performance on a test system with a benchmark.

Let them know where the full documentation for fastpath is, but to help ease them into the concepts, we've build some utility scripts to make it easier to get started.

Create the needed sections to walk the user through the following steps:

1. bring up a c8g.24xl. this will be known as the "build" machine.  we refer the user to follow the existing LP if they have questions on how to do that:  http://localhost:1313/learning-paths/servers-and-cloud-computing/csp/

2. to satisfy the Fastpath instructions at https://fastpath.docs.arm.com/en/latest/user-guide/buildkernel.html, next we ask the user to run /install-guides/kernel-build/#install-and-clone to install build dependencies and clone tuxmake.

3. Next we instruct the user to build the kernel with Fastpath options by running:

http://localhost:1313/install-guides/kernel-build/#2-custom-tags-with-fastpath-enabled

At this point, the kernel will begin building with Fastpath options.  We will refer the user to the existing install guides (Fastpath and Kernel-Install) for any questions on this step.

4. Once the build is complete, we ask the user to spin up a second node, a c8g.2xl.  This will be known as the "fastpath" machine.

5. On the fastpath machine, we instruct the user to run http://localhost:1313/install-guides/kernel-build/#install-and-clone once again.

6. We ask them to copy the built kernel artifacts from the build machine to the fastpath machine. This is done by executing the pull_kernel_artifacts.sh script.

The script will need to be given a --host parameter, which is the private IP of the build machine.  Show the user how to pull the private IP from the build instance via a CLI command.  

7.  Upon successful copying of the artifacts, we ask the user to stop the build instance via a sudo init 0 command.  Also mention to them to terminate it when they are completely done with it to avoid incurring extra costs.
At this point we have only the fastpath machine left.


8. Next instruct the user to run configure_fastpath_host.sh on the fastpath machine, using localhost as the --host parameter.

This will install all fastpath requirements on the fastpath machine.

At this point, we have the fastpath host with the kernels to test and the fastpath software ready to begin.  Make sure the guide provides the bin/activate command for fastpath for them to run before testing if they end up relogging into the machine.

9. Now we ask the user to spin up a third instance, a c8g.12xl.  This will be known as the system under test, aka "sut" machine.

10.  Once it comes up,  from the fastpath machine, instruct them to run configure_fastpath_sut.sh, giving it the private IP of the sut machine as the --host parameter.  Once again remind them how to get that IP via the CLI.

11. At this point, we should have the fastpath and SUT instances configured and running.  To test  that everything is working, we ask the user to run the following command:

```commandline
source ~/venv/bin/activate
./fastpath/fastpath/fastpath sut fingerprint --user fpuser SUT_PRIVATE_IP
```

This should return a fingerprint of the SUT if everything is working correctly.

12. Once the system is validated, the next step is to generate the test yaml.  To do this, the user is instructed to run scripts/generate_plan.sh, which generates the plan yaml based on the SUT private IP and the kernels built earlier.

When this is done running, it echos out the test name, and the command lines to run after fastpath runs to view individual and combined results.


13. With the plan yaml in place, the user is instructed to run the fastpath benchmark via:

```commandline
fastpath plan exec --output results/ plan.yaml
```

14.  remind the user as a note that they should  


15. When the fastpath benchmark is complete, we ask the user to review the results in the results/ folder via the following commands:

a. list all results (cli from the generate plan output)
b. Show results of the benchmark for a single machine (cli from the generate plan output)
c. Show results of the benchmark from both machines (cli from the generate plan output)

Let them know by default if they run the fastpath again against the same YAML, they will need to change the name of the sut.name, or provide a new results folder.  If they choose to use a different name with the same results folder, they must use the append flag to store the new results in the existing folder.


The concluding section should reference what we did, but also reference the official Fastpath and Tuxmake and Kernel Install Guide documentation links for further reading and exploration.



Based on this What I'd like to refactor first:

1. Number of scripts
2. Number of script-related steps
3. 

 
