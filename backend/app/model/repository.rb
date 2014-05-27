class Repository < Sequel::Model(:repository)
  include ASModel

  set_model_scope :global
  corresponds_to JSONModel(:repository)

  def validate
    super
    validates_unique(:repo_code, :message => "short name already in use")
    validates_presence(:repo_code, :message => "You must supply a short name for your repository")
    validates_presence(:name, :message => "You must give your repository a name")
  end


  def self.exists?(id)
    not Repository[id].nil?
  end


  def self.global_repo_id
    self[:repo_code => Repository.GLOBAL].id
  end


  def self.GLOBAL
    # The repository code indicating that this group is global to all repositories
    ASConstants::Repository.GLOBAL
  end


  def after_create

    if self.repo_code == Repository.GLOBAL
      # No need for standard groups on this one.
      return
    end

    standard_groups = [{
                         :group_code => "repository-managers",
                         :description => "Managers of the #{repo_code} repository",
                         :grants_permissions => ["manage_repository", "update_location_record", "update_subject_record",
                                                 "update_agent_record", "update_accession_record", "update_resource_record",
                                                 "update_digital_object_record", "update_event_record", "view_repository",
                                                 "delete_archival_record", "suppress_archival_record",
                                                 "manage_subject_record", "manage_agent_record"]
                       },
                       {
                         :group_code => "repository-archivists",
                         :description => "Archivists of the #{repo_code} repository",
                         :grants_permissions => ["update_subject_record", "update_agent_record", "update_accession_record",
                                                 "update_resource_record", "update_digital_object_record", "update_event_record",
                                                 "view_repository", "manage_subject_record", "manage_agent_record"]
                       },
                       {
                         :group_code => "repository-project-managers",
                         :description => "Project managers of the #{repo_code} repository",
                         :grants_permissions => ["view_repository", "update_accession_record", "update_resource_record",
                                                 "update_digital_object_record", "update_event_record", "update_subject_record",
                                                 "update_agent_record", "delete_archival_record", "suppress_archival_record",
                                                 "manage_subject_record", "manage_agent_record",
                                                 'merge_agents_and_subjects']
                       },
                       {
                         :group_code => "repository-advanced-data-entry",
                         :description => "Advanced Data Entry users of the #{repo_code} repository",
                         :grants_permissions => ["view_repository", "update_accession_record", "update_resource_record",
                                                 "update_digital_object_record", "update_event_record", "update_subject_record",
                                                 "update_agent_record", "manage_subject_record", "manage_agent_record"]
                       },
                       {
                         :group_code => "repository-basic-data-entry",
                         :description => "Basic Data Entry users of the #{repo_code} repository",
                         :grants_permissions => ["view_repository", "update_accession_record", "update_resource_record",
                                                 "update_digital_object_record"]
                       },
                       {
                         :group_code => "repository-viewers",
                         :description => "Viewers of the #{repo_code} repository",
                         :grants_permissions => ["view_repository"]
                       }]

    RequestContext.open(:repo_id => self.id) do
      standard_groups.each do |group_data|
        Group.create_from_json(JSONModel(:group).from_hash(group_data),
                               :repo_id => self.id)
      end
    end

    Notifications.notify("REPOSITORY_CHANGED")
  end


  def delete
    Group.filter(:repo_id => self.id).each do |group|
      group.delete
    end

    super

    Notifications.notify("REPOSITORY_CHANGED")
  end


  def assimilate(other_repository)
    ASModel.all_models.each do |model|
      if model.model_scope(true) == :repository
        model.transfer_all(other_repository, self)
      end
    end
  end


  def self.sequel_to_jsonmodel(objs, opts = {})
    jsons = super

    jsons.zip(objs).each do |json, obj|
      if (agent_id = obj.agent_representation_id)
        json["agent_representation"] = {
          "ref" => JSONModel(:agent_corporate_entity).uri_for(agent_id)
        }
      end
    end

    jsons
  end

end
