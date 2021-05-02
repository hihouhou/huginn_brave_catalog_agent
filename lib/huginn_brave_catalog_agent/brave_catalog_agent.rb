module Agents
  class BraveCatalogAgent < Agent
    include FormConfigurable

    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description do
      <<-MD
      The huginn catalog agent checks if new campaign is available.

      `debug` is used to verbose mode.

      `changes_only` is only used to emit event about a currency's change.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:
        {
          "creativeSets": [
            {
              "creatives": [
                {
                  "creativeInstanceId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                  "type": {
                    "code": "notification_all_v1",
                    "name": "notification",
                    "platform": "all",
                    "version": 1
                  },
                  "payload": {
                    "body": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                    "title": "XXXXX",
                    "targetUrl": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
                  }
                },
                {
                  "creativeInstanceId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                  "type": {
                    "code": "notification_all_v1",
                    "name": "notification",
                    "platform": "all",
                    "version": 1
                  },
                  "payload": {
                    "body": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                    "title": "XXXXX",
                    "targetUrl": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
                  }
                },
                {
                  "creativeInstanceId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                  "type": {
                    "code": "notification_all_v1",
                    "name": "notification",
                    "platform": "all",
                    "version": 1
                  },
                  "payload": {
                    "body": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                    "title": "XXXXX",
                    "targetUrl": "https://XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
                  }
                }
              ],
              "segments": [
                {
                  "code": "XXXXXXXXXX",
                  "name": "XXXXXXXXXXXXXXXX"
                }
              ],
              "oses": [
        
              ],
              "conversions": [
        
              ],
              "creativeSetId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
              "perDay": 2,
              "totalMax": 60
            }
          ],
          "dayParts": [
        
          ],
          "geoTargets": [
            {
              "code": "XX",
              "name": "XXXXXX"
            }
          ],
          "campaignId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
          "startAt": "XXXXXXXXXXXXXXXXXXXXXXXX",
          "endAt": "XXXXXXXXXXXXXXXXXXXXXXXX",
          "dailyCap": 2,
          "advertiserId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
          "priority": 1
        }
    MD

    def default_options
      {
        'debug' => 'false',
        'expected_receive_period_in_days' => '2',
        'changes_only' => 'true'
      }
    end

    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :debug, type: :boolean

    def validate_options
      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      fetch
    end

    private

    def fetch
      uri = URI.parse("https://ads-serve.brave.com/v4/catalog")
      response = Net::HTTP.get_response(uri)

      log "request  status : #{response.code}"

      payload = JSON.parse(response.body)

      if interpolated['debug'] == 'true'
        log payload
      end
      if interpolated['changes_only'] == 'true'
        if payload.to_s != memory['last_status']
          if "#{memory['last_status']}" == ''
            payload['campaigns'].each do |campaign|
              creatives = campaign['creativeSets']
              creatives[0]['creatives'].each do |creative|
                creative[:startAt] = campaign['startAt']
                creative[:endAt] = campaign['endAt']
                creative[:campaignId] = campaign['campaignId']
                creative[:geoTargets] = campaign['geoTargets']
                creative[:advertiserId] = campaign['advertiserId']
                create_event payload: creative
            end
          end
          else
            log "not equal"
            last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil", ": null").gsub(":endAt", "\"endAt\"").gsub(":startAt", "\"startAt\"").gsub(":campaignId", "\"campaignId\"").gsub(":geoTargets", "\"geoTargets\"").gsub(":advertiserId", "\"advertiserId\"").gsub!("\\u", "\\\\\\u")
            last_status = JSON.parse(last_status)
            payload['campaigns'].each do |campaign|
              creatives = campaign['creativeSets']
              creatives[0]['creatives'].each do |creative|
                found = false
                if interpolated['debug'] == 'true'
                  log "#{found}"
                end
                last_status['campaigns'] .each do |campaignbis|
#this check is neeeded because segments are not in the same order
                  if campaign['campaignId'] == campaignbis['campaignId']
                      found = true
                      if interpolated['debug'] == 'true'
                        log "#{found}"
                      end
                  end
                end
                if found == false
                  creative[:startAt] = campaign['startAt']
                  creative[:endAt] = campaign['endAt']
                  creative[:campaignId] = campaign['campaignId']
                  creative[:geoTargets] = campaign['geoTargets']
                creative[:advertiserId] = campaign['advertiserId']
                  create_event payload: creative
                end
              end
            end
          end
          memory['last_status'] = payload.to_s
        end
      else
        create_event payload: payload
        if payload.to_s != memory['last_status']
          memory['last_status'] = payload.to_s
        end
      end
    end
  end
end
