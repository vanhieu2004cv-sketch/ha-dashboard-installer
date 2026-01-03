#!/bin/bash

CONFIG_DIR="/config"
DASHBOARD_FILE="$CONFIG_DIR/dashboard.yaml"
CONFIG_FILE="$CONFIG_DIR/configuration.yaml"

echo "▶ Copy dashboard.yaml"
wget -q -O "$DASHBOARD_FILE" \
https://raw.githubusercontent.com/vanhieu2004cv-sketch/ha-dashboard-installer/main/dashboard.yaml

# Kiểm tra xem cấu hình my-dashboard đã tồn tại chưa
if ! grep -q "my-dashboard:" "$CONFIG_FILE"; then
  echo "▶ Add lovelace dashboard config"
  cat <<EOF >> "$CONFIG_FILE"

# ============================================
# INPUT TEXT - CHIA THÀNH NHIỀU PHẦN (Mỗi phần 255 ký tự)
# ============================================
input_text:
  # Switches - Chia thành 5 phần
  esp32_selected_switches_1:
    name: ESP32 Selected Switches Part 1
    initial: ""
    max: 255
  esp32_selected_switches_2:
    name: ESP32 Selected Switches Part 2
    initial: ""
    max: 255
  esp32_selected_switches_3:
    name: ESP32 Selected Switches Part 3
    initial: ""
    max: 255
  esp32_selected_switches_4:
    name: ESP32 Selected Switches Part 4
    initial: ""
    max: 255
  esp32_selected_switches_5:
    name: ESP32 Selected Switches Part 5
    initial: ""
    max: 255
    
  # Sensors - Chia thành 5 phần
  esp32_selected_sensors_1:
    name: ESP32 Selected Sensors Part 1
    initial: ""
    max: 255
  esp32_selected_sensors_2:
    name: ESP32 Selected Sensors Part 2
    initial: ""
    max: 255
  esp32_selected_sensors_3:
    name: ESP32 Selected Sensors Part 3
    initial: ""
    max: 255
  esp32_selected_sensors_4:
    name: ESP32 Selected Sensors Part 4
    initial: ""
    max: 255
  esp32_selected_sensors_5:
    name: ESP32 Selected Sensors Part 5
    initial: ""
    max: 255

# ============================================
# HELPER SCRIPT - GỘP TẤT CẢ CÁC PHẦN
# ============================================
script:
  esp32_get_all_switches:
    alias: Get All Switches
    sequence:
      - stop: ""
        response_variable: all_switches
    variables:
      all_switches: >
        {% set parts = [
          states('input_text.esp32_selected_switches_1'),
          states('input_text.esp32_selected_switches_2'),
          states('input_text.esp32_selected_switches_3'),
          states('input_text.esp32_selected_switches_4'),
          states('input_text.esp32_selected_switches_5')
        ] %}
        {{ parts | join(',') | replace(',,', ',') | trim(',') }}
        
  esp32_get_all_sensors:
    alias: Get All Sensors
    sequence:
      - stop: ""
        response_variable: all_sensors
    variables:
      all_sensors: >
        {% set parts = [
          states('input_text.esp32_selected_sensors_1'),
          states('input_text.esp32_selected_sensors_2'),
          states('input_text.esp32_selected_sensors_3'),
          states('input_text.esp32_selected_sensors_4'),
          states('input_text.esp32_selected_sensors_5')
        ] %}
        {{ parts | join(',') | replace(',,', ',') | trim(',') }}

# ============================================
# SCRIPT - TOGGLE ENTITY (Tự động chia vào phần phù hợp)
# ============================================
  esp32_toggle_entity:
    alias: Toggle Entity Selection
    mode: parallel
    max: 50
    fields:
      entity_id:
        description: Entity to toggle
      entity_type:
        description: Type (switch or sensor)
    sequence:
      - variables:
          # Lấy tất cả các phần
          all_parts: >
            {% if entity_type == 'switch' %}
              [
                'input_text.esp32_selected_switches_1',
                'input_text.esp32_selected_switches_2',
                'input_text.esp32_selected_switches_3',
                'input_text.esp32_selected_switches_4',
                'input_text.esp32_selected_switches_5'
              ]
            {% else %}
              [
                'input_text.esp32_selected_sensors_1',
                'input_text.esp32_selected_sensors_2',
                'input_text.esp32_selected_sensors_3',
                'input_text.esp32_selected_sensors_4',
                'input_text.esp32_selected_sensors_5'
              ]
            {% endif %}
          
          # Ghép tất cả nội dung
          all_content: >
            {% if entity_type == 'switch' %}
              {% set parts = [
                states('input_text.esp32_selected_switches_1'),
                states('input_text.esp32_selected_switches_2'),
                states('input_text.esp32_selected_switches_3'),
                states('input_text.esp32_selected_switches_4'),
                states('input_text.esp32_selected_switches_5')
              ] %}
            {% else %}
              {% set parts = [
                states('input_text.esp32_selected_sensors_1'),
                states('input_text.esp32_selected_sensors_2'),
                states('input_text.esp32_selected_sensors_3'),
                states('input_text.esp32_selected_sensors_4'),
                states('input_text.esp32_selected_sensors_5')
              ] %}
            {% endif %}
            {{ parts | join(',') | replace(',,', ',') | trim(',') }}
          
          # Kiểm tra entity đã tồn tại chưa
          is_selected: >
            {{ entity_id in all_content.split(',') }}
      
      # Nếu đã chọn -> Xóa
      - choose:
          - conditions:
              - condition: template
                value_template: "{{ is_selected }}"
            sequence:
              # Tìm và xóa entity khỏi phần chứa nó
              - repeat:
                  for_each: "{{ all_parts }}"
                  sequence:
                    - variables:
                        part_content: "{{ states(repeat.item) }}"
                        part_list: "{{ part_content.split(',') | map('trim') | list }}"
                    - if:
                        - condition: template
                          value_template: "{{ entity_id in part_list }}"
                      then:
                        - service: input_text.set_value
                          target:
                            entity_id: "{{ repeat.item }}"
                          data:
                            value: >
                              {% set filtered = part_list | reject('equalto', entity_id) | list %}
                              {{ filtered | join(',') }}
        
        # Nếu chưa chọn -> Thêm vào phần còn chỗ trống
        default:
          - repeat:
              for_each: "{{ all_parts }}"
              sequence:
                - variables:
                    part_content: "{{ states(repeat.item) }}"
                    new_content: >
                      {% if part_content | length == 0 %}
                        {{ entity_id }}
                      {% else %}
                        {{ part_content ~ ',' ~ entity_id }}
                      {% endif %}
                
                # Nếu phần này còn đủ chỗ (< 255 ký tự) thì thêm vào
                - if:
                    - condition: template
                      value_template: "{{ new_content | length <= 255 }}"
                  then:
                    - service: input_text.set_value
                      target:
                        entity_id: "{{ repeat.item }}"
                      data:
                        value: "{{ new_content }}"
                    - stop: "Added to {{ repeat.item }}"

# ============================================
# SCRIPT - XÓA TẤT CẢ SWITCHES
# ============================================
  esp32_clear_switches:
    alias: Clear All Switches
    sequence:
      - service: input_text.set_value
        target:
          entity_id:
            - input_text.esp32_selected_switches_1
            - input_text.esp32_selected_switches_2
            - input_text.esp32_selected_switches_3
            - input_text.esp32_selected_switches_4
            - input_text.esp32_selected_switches_5
        data:
          value: ""

# ============================================
# SCRIPT - XÓA TẤT CẢ SENSORS
# ============================================
  esp32_clear_sensors:
    alias: Clear All Sensors
    sequence:
      - service: input_text.set_value
        target:
          entity_id:
            - input_text.esp32_selected_sensors_1
            - input_text.esp32_selected_sensors_2
            - input_text.esp32_selected_sensors_3
            - input_text.esp32_selected_sensors_4
            - input_text.esp32_selected_sensors_5
        data:
          value: ""

# =============================================
lovelace:
  dashboards:
    my-dashboard:
      mode: yaml
      title: My Dashboard
      icon: mdi:view-dashboard
      show_in_sidebar: true
      filename: dashboard.yaml
EOF
else
  echo "ℹ Dashboard my-dashboard already exists, skip"
fi

echo "▶ Restart Home Assistant"
ha core restart

echo "✅ DONE: Dashboard installed"
