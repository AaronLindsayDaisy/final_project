class Experiment < ActiveRecord::Base
  ratyrate_rateable "name"
  belongs_to :user

  has_and_belongs_to_many :concepts

  has_attached_file :uploaded_file

  validates_attachment_content_type :uploaded_file, :content_type => ['image/jpeg', 'image/png', 'image/pdf']

  has_many :comments, as: :commentable

  has_many :experiment_votes
  accepts_nested_attributes_for :experiment_votes

  has_many :materials, dependent: :destroy
  accepts_nested_attributes_for :materials,
      reject_if: :all_blank,
      allow_destroy: true

  has_many :instructions, dependent: :destroy
  accepts_nested_attributes_for :instructions,
      reject_if: :all_blank,
      allow_destroy: true

  validates :description, :complete_time, :name, :age, presence: true

  validates_format_of :youtube_link,
      :allow_blank => true,
      :with => /\A(?:https?:\/\/)?(?:www\.)?youtu(?:\.be|be\.com)\/(?:watch\?v=)?([\w-]{10,})\z/,
      :on => :create

  def self.text_search(query)
    query = query.downcase
    q = "%#{query}%"
    joins(:materials)
        .where("lower(name) LIKE ? OR lower(description) LIKE ? OR lower(item) LIKE ?", q, q, q).uniq
  end

  def self.by_votes
    all.sort_by {|e| e.experiment_votes.count}.reverse
  end

  def votes
    read_attribute(:votes) || experiment_votes.sum(:value)
  end

  def return_age
    if self.age == 1
      "3 & Under"
    elsif self.age == 2
      "4-6"
    elsif self.age == 3
      "7-9"
    elsif self.age == 4
      "10 & up"
    end
  end

  def self.order_by_mess
    (all.sort_by {|e| e.average("name").nil? ? 0 : e.average("name").avg}).reverse
  end

  def self.order_by_mess_complete_time
    (all.sort_by {|e| [e.average("name").nil? ? 0 : e.average("name").avg, e.complete_time]}).reverse
  end

  def concept_parents
    array = []
    concepts.each do |c|
      array += c.parents
    end
    array.uniq
  end

  def concept_children
    array = []
    concepts.each do |c|
      array += c.children
    end
    array.uniq
  end

  def find_concept
    self.concepts.sample
  end

  def self.first_experiment(concept, experiment) #show recommended
    concept_experiment = []
    if experiment.concepts.count == 1 && concept.experiments.count == 1
      if Experiment.by_votes[0] != experiment
        top_experiment = Experiment.by_votes[0]
      else
        top_experiment = Experiment.by_votes[1]
      end
      concept_experiment << top_experiment.concepts.sample << top_experiment
    elsif concept.experiments.where.not(name: experiment.name).blank? #if current concept doesn't have any more experiments, do this
      concept = experiment.concepts.where.not(name: concept.name).sample #look for other concepts for the current experiment
      experiment = concept.experiments.where.not(name: experiment.name).sample
      concept_experiment << concept << experiment
    else
      # Another Experiment about concept.name
      experiment = concept.experiments.where.not(name: experiment.name).sample
      concept_experiment << concept << experiment
    end
  end

  def self.second_experiment(concept, experiment) #show extended learning
    concept_experiment = []
    if concept.children.count > 0
      random_child = concept.children.sample
      random_child_experiment = random_child.experiments.sample
      concept_experiment << random_child << random_child_experiment
    else #work on your fundamenetals
      random_parent = concept.parents.sample
      random_parent_experiment = random_parent.experiments.sample
      concept_experiment << random_parent << random_parent_experiment
    end
  end
end
