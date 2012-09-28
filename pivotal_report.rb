require 'rubygems'
require 'thor'
require 'pivotal-tracker'
require 'erubis'

PivotalTracker::Client.use_ssl = true


class PivotalReport < Thor
	desc "summary PROJECT_ID", "runs the end of iteration report"

	def summary(project_id, api_token)
		PivotalTracker::Client.token = api_token
		project = PivotalTracker::Project.find(project_id)
		allStories = PivotalTracker::Iteration.current(project).stories
		acceptedStories = allStories.select { |story| story.current_state == 'accepted' }.sort { |x,y| x.story_type <=> y.story_type }

		allStories.each do |story| 
			puts '---------------'
			puts story.story_type
			puts story.name
			puts story.url
			puts story.labels
			puts story.current_state
		end

		
		grcSupportTicket = 'grc support ticket'
		small = 1
		medium = 5
		large = 10

		featureStories = acceptedStories.select{ |story| story.story_type == 'feature' }

		smallStoriesCount = featureStories.select{ |story| story.estimate == small }.length
		mediumStoriesCount = featureStories.select{ |story| story.estimate == medium }.length
		largeStoriesCount = featureStories.select{ |story| story.estimate == large }.length

		acceptedFeatureCount = featureStories.length
		bugCount = acceptedStories.select{ |story| story.story_type == 'bug' }.length
		choreCount = acceptedStories.select{ |story| story.story_type == 'chore' and (story.labels.nil? || !story.labels.include?(grcSupportTicket)) }.length
		grcSupportTicketCount = acceptedStories.select{ |story| story.story_type == 'chore' and (!story.labels.nil? && story.labels.include?(grcSupportTicket)) }.length
		inFlightFeatureCount = allStories.select{ |story| story.story_type == 'feature' and story.current_state != 'accepted' and story.current_state != 'unstarted' }.length

		puts "Accepted Features: #{acceptedFeatureCount}"
		puts "In Flight Features: #{inFlightFeatureCount}"
		puts "Bugs: #{bugCount}"
		puts "Chores: #{choreCount}"
		puts "GRC Support Tickets: #{grcSupportTicketCount}"
		puts "Total Stories: #{acceptedStories.count}"

		story_percents = { 
			:acceptedPercentage =>  getPercentage(acceptedFeatureCount),
			:inFlightPercentage => getPercentage(inFlightFeatureCount),
			:bugsPercentage => getPercentage(bugCount),
			:choresPercentage => getPercentage(choreCount),
			:grcSupportTicketsPercentage => getPercentage(grcSupportTicketCount)
		}

		rhtml = Erubis::Eruby.new File.read('end_of_iteration_report.rhtml')

		File.open("end_of_iteration_report.html", "w") {|file| file.puts rhtml.result(story_percents) }
	end

	no_tasks {
		def getPercentage(numberOfStories)
			topOfStoryChart = 20.0
			(numberOfStories.to_f/topOfStoryChart * 100.0).round
		end
	}
end

PivotalReport.start