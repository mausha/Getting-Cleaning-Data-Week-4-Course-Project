###############################################################################
# This is an R script that is part of the Coursera Getting and Cleaning Data 
# Course Project and it does the following:
# 1) Merges the training and the test sets to create one data set. 
# 2) Extracts only the measurements on the mean and standard deviation for each 
#    measurement.
# 3) Uses descriptive activity names to name the activities in the data set 
# 4) Appropriately labels the data set with descriptive variable names. 
# 5) From the data set in step 4, creates a second, independent tidy data set 
#    with the average of each variable for each activity and each subject.
###############################################################################

###############################################################################
# Load all required libraries.
library(dplyr)
library(tidyr)
library(tidyselect)

###############################################################################
# 0) Download and unzip the data files and then load all of the required 
#    data from the data set. 

# Download the zip file if it doesn't already exist in the project folder
# and then unzip it.
if (!file.exists("getdata_projectfiles_UCI_HAR_Dataset.zip")) {
  download.file("https://d396qusza40orc.cloudfront.net/getdata%2Fprojectfiles%2FUCI%20HAR%20Dataset.zip", 
                destfile = "getdata_projectfiles_UCI_HAR_Dataset.zip")
  unzip("getdata_projectfiles_UCI_HAR_Dataset.zip")
}

# Load the activity and measurement labels, converting the id columns to integer.
activityLabels <- as_tibble(read.csv("UCI HAR Dataset\\activity_labels.txt", header=FALSE, 
                                       skip=0, stringsAsFactors = FALSE, sep = " ",
                                     col.names = c("activity_id", "activity_label"),
                                     colClasses = c("integer", "character")))
measurementLabels <- as_tibble(read.csv("UCI HAR Dataset\\features.txt", header=FALSE, 
                                       skip=0, stringsAsFactors = FALSE, sep = " ",
                                       col.names = c("measure_id", "measure_label"),
                                       colClasses = c("integer", "character")))

# Cleanup measurement labels removing/replacing special characters to make the labels
# appropriate for use as column names in a tibble.
# - replace "()" with "_val"
# - drop any remaining ")" at the end of a label
# - replace remaining special characters with "_" these include: ",", "-", "(", and ")"
measurementLabels <- transmute(measurementLabels, 
                               measure_label = gsub("\\(\\)", "_val", measure_label)) %>%
                    transmute(measure_label = gsub("\\)$", "", measure_label)) %>%
                    transmute(measure_label = gsub("\\-", "_", measure_label)) %>%
                    transmute(measure_label = gsub("\\,", "_", measure_label)) %>%
                    transmute(measure_label = gsub("\\(", "_", measure_label)) %>%
                    transmute(measure_label = gsub("\\)", "_", measure_label))

# Load the training data and apply the appropriate column names.
trainMeasureData <- as_tibble(read.fwf("UCI HAR Dataset\\train\\X_train.txt", 
                                       widths=rep.int(16,561),
                                       col.names = pull(measurementLabels, measure_label),
                                       colClasses = c("numeric")))
trainActivityData <- as_tibble(read.csv("UCI HAR Dataset\\train\\y_train.txt", header=FALSE, 
                                        skip=0, stringsAsFactors = FALSE, sep = " ",
                                        col.names = c("activity_id"),
                                        colClasses = c("integer")))
trainSubjectData <- as_tibble(read.csv("UCI HAR Dataset\\train\\subject_train.txt", header=FALSE, 
                                        skip=0, stringsAsFactors = FALSE, sep = " ",
                                       col.names = c("subject_id"),
                                       colClasses = c("integer")))

# Load the test data and apply the appropriate column names.
testMeasureData <- as_tibble(read.fwf("UCI HAR Dataset\\test\\X_test.txt", 
                                       widths=rep.int(16,561),
                                      col.names = pull(measurementLabels, measure_label),
                                      colClasses = c("numeric")))
testActivityData <- as_tibble(read.csv("UCI HAR Dataset\\test\\y_test.txt", header=FALSE, 
                                       skip=0, stringsAsFactors = FALSE, sep = " ",
                                       col.names = c("activity_id"),
                                       colClasses = c("integer")))
testSubjectData <- as_tibble(read.csv("UCI HAR Dataset\\test\\subject_test.txt", header=FALSE, 
                                      skip=0, stringsAsFactors = FALSE, sep = " ",
                                      col.names = c("subject_id"),
                                      colClasses = c("integer")))


###############################################################################
# 1) Merge the training and the test sets to create one data set. 
#    - remove intermediate data sets, when no longer needed, to free memory usage

# Assign the activity for each measurement record and bind to the appropriate measurement data set
trainActivityWithLabels <- inner_join(trainActivityData, activityLabels, by = c("activity_id"))
trainData <- cbind(trainSubjectData, trainActivityWithLabels, trainMeasureData)
rm(trainSubjectData, trainActivityData, trainActivityWithLabels, trainMeasureData)

testActivityWithLabels <- inner_join(testActivityData, activityLabels, by = c("activity_id"))
testData <- cbind(testSubjectData, testActivityWithLabels, testMeasureData)
rm(testSubjectData, testActivityData, testActivityWithLabels, testMeasureData)

# Combine the train and test data together into a single data set.
allData <- rbind(trainData, testData)
rm(trainData, testData)


###############################################################################
# 2) Extract only the measurements on the mean and standard deviation for each 
#    measurement. The features_info.txt file in the original data set indicates
#    that columns containing mean and standard deviation values contained 
#    "mean()" and "std()" respectively and earlier when we cleaned up the measurement 
#    labels, "()" was replaced by "_val". Therefore the labels that had "mean()" and 
#    "std()" in them now have "mean_val" and "std_val" instead and these are the 
#    strings we need to match to find all of the measurement columns containing mean
#    and standard deviation values.
allDataNames <- names(allData)
selectedColumns <- c(vars_select(allDataNames, one_of(c("subject_id", "activity_label"))),
                     vars_select(allDataNames, contains("mean_val")),
                     vars_select(allDataNames, contains("std_val")))
meanAndStdData <- select(allData, all_of(selectedColumns))
rm(allData, allDataNames)


###############################################################################
# 3) Use descriptive activity names to name the activities in the data set 
#    - already done as part of step-1: the activity data was joined with the 
#      activity labels data and then those columns were bound to the train and
#      test measurement data (the activity_label column provides the descriptive 
#      activity name)


###############################################################################
# 4) Appropriately label the data set with descriptive variable names. 
#    - already done: all of the data columns had the appropriate labels applied 
#      as column names when the data was read from its data files.


###############################################################################
# 5) From the data set in step 4, create a second, independent tidy data set 
#    with the average of each variable for each activity and each subject.
#    The new tidy data set is created with the following steps:
#    - Sort the data by subject_id, followed by activity to make the result easier to read
#    - Group the data by subject_id and then activity
#    - summarize all of the remaining columns by taking the mean for each measurement
#    - ungroup the resulting data set to remove the remaining grouping
averageBySubjectAndActivity <- arrange(meanAndStdData, subject_id, activity_label) %>%
                               group_by(subject_id, activity_label) %>%
                               summarize_all(mean) %>%
                               ungroup()
rm(meanAndStdData)


###############################################################################
# 6) Save the new tidy data set created in step 5 above as a txt file created 
#    with write.table() using row.name=FALSE.
write.table(averageBySubjectAndActivity, 
            file = "Getting-Cleaning-Data-Course-Tidy-Data.txt", 
            row.names = FALSE)


###############################################################################
# Code to load and view the tidy data that was just written out to the text file.
# Uncomment and run the following code: 
#
# data <- read.table("Getting-Cleaning-Data-Course-Tidy-Data.txt", header = TRUE)
# View(data)

###############################################################################
#############################       End of file.        #######################
###############################################################################