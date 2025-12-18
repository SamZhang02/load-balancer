package config

import (
	"os"
	"gopkg.in/yaml.v2"
)

type ServerConfig struct {
	Port int32 `yaml:"port"`
}

type UpstreamConfig struct {
	App AppConfig `yaml:"app"`
}

type AppConfig struct {
	Backends []string `yaml:"backends"`
	Fail FailConfig `yaml:"fail"`
}

type FailConfig struct {
	MaxFail int32 `yaml:"max_fail"`
	FailTimeout int32 `yaml:"fail_timeout"`
	FailTimeframe int32 `yaml:"fail_timeframe"`
}

type Config struct {
	Server ServerConfig `yaml:"server"`
	Upstream UpstreamConfig `yaml:"upstream"`
}

func LoadConfig(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }

    var cfg Config
    if err := yaml.Unmarshal(data, &cfg); err != nil {
        return nil, err
    }

    return &cfg, nil
}

